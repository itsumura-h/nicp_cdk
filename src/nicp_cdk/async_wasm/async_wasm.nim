## async_wasm module
## =============
##
## このモジュールはNimのasyncdispatchモジュールのインターフェースを踏襲し、
## WebAssembly環境下で非同期処理が行えるようにするものです。
## EmscriptenのAsyncify技術に着想を得ています。

{.experimental: "codeReordering".}

import macros
import tables
import strutils
import times
import heapqueue
import options
import math

# コールバックをすぐ実行するための前方宣言
proc callSoon*(cbproc: proc() {.closure, gcsafe.})

# ================================================================================
# 型定義
# ================================================================================

type
  FutureBase* = ref object of RootObj  ## 全てのFutureの基底となるオブジェクト
    callbacks: seq[proc() {.closure, gcsafe.}] # 完了時に呼ばれるコールバック
    finished: bool                        # 完了したかどうか
    error: ref Exception                  # エラーが発生したらここに格納
    stackTrace: string                    # エラー発生時のスタックトレース

  Future*[T] = ref object of FutureBase ## 値を持つFutureオブジェクト
    when T isnot void:
      value: T                           # 完了時に返される値

  FutureVar*[T] = distinct Future[T]   ## 可変を表すFuture

  FutureStream*[T] = ref object of RootObj ## ストリーム処理のためのFuture
    future: Future[seq[T]]                ## 内部で使用するFuture
    finished: bool                        ## 完了したかどうか

  PDispatcher* = ref object of RootObj    ## ディスパッチャー
    callbacks: seq[proc() {.closure, gcsafe.}]

  AsyncError* = object of CatchableError ## 非同期処理のエラー

  Callback* = proc (): bool {.closure, gcsafe.}  ## コールバック関数の型

  WasmAsyncState = enum
    wasNormal
    wasUnwinding
    wasRewinding

var 
  globalDispatcher {.threadvar.}: PDispatcher  ## グローバルディスパッチャ
  wasmAsyncState {.threadvar.}: WasmAsyncState ## WASMでの非同期状態
  currentCallIndex {.threadvar.}: int          ## 現在のコール位置
  asyncifyDataAddr {.threadvar.}: int          ## AsyncifyデータのアドレスWAS

# ================================================================================
# 基本関数
# ================================================================================

proc newDispatcher*(): PDispatcher =
  ## 新しいディスパッチャーを作成します
  new(result)
  result.callbacks = @[]

proc getGlobalDispatcher*(): PDispatcher =
  ## グローバルディスパッチャーを取得します。まだ存在しない場合は新しく作成します。
  if globalDispatcher.isNil:
    globalDispatcher = newDispatcher()
  result = globalDispatcher

proc setGlobalDispatcher*(disp: PDispatcher) =
  ## グローバルディスパッチャーを設定します
  globalDispatcher = disp

proc newFuture*[T](fromProc: string = "unknown"): Future[T] =
  ## 新しいFutureを作成します
  new(result)
  result.callbacks = @[]
  result.finished = false

proc newFutureStream*[T](fromProc: string = "unknown"): FutureStream[T] =
  ## 新しいFutureStreamを作成します
  new(result)
  result.future = newFuture[seq[T]](fromProc)
  result.future.value = @[]
  result.finished = false

# ================================================================================
# Future操作
# ================================================================================

proc callback*[T](future: Future[T], cb: proc() {.closure, gcsafe.}) =
  ## Futureにコールバックを追加します
  if future.finished:
    callSoon(cb)
  else:
    future.callbacks.add(cb)

proc complete*[T](future: Future[T], val: T) =
  ## Futureに値をセットして完了状態にします
  if future.finished:
    raise newException(AssertionDefect, "Future is already finished")
  
  future.value = val
  future.finished = true
  
  for cb in future.callbacks:
    cb()
  
  future.callbacks = @[]

proc complete*(future: Future[void]) =
  ## void型Futureを完了状態にします
  if future.finished:
    raise newException(AssertionDefect, "Future is already finished")
  
  future.finished = true
  
  for cb in future.callbacks:
    cb()
  
  future.callbacks = @[]

proc fail*[T](future: Future[T], error: ref Exception) =
  ## Futureをエラー状態で完了させます
  if future.finished:
    raise newException(AssertionDefect, "Future is already finished")
  
  future.error = error
  future.finished = true
  
  for cb in future.callbacks:
    cb()
  
  future.callbacks = @[]

proc read*[T](future: Future[T]): T =
  ## Futureから値を読み取ります。未完了の場合はエラーになります。
  if not future.finished:
    raise newException(AsyncError, "Future still in progress")
  
  if future.error != nil:
    raise future.error
  
  when T isnot void:
    result = future.value

proc readError*(future: FutureBase): ref Exception =
  ## Futureからエラーを読み取ります
  if not future.finished:
    raise newException(AsyncError, "Future still in progress")
  
  result = future.error

proc finished*(future: FutureBase): bool =
  ## Futureが完了しているかどうかを確認します
  result = future.finished

proc failed*(future: FutureBase): bool =
  ## Futureがエラーで完了したかどうかを確認します
  result = future.finished and future.error != nil

# FutureVar 操作
proc mget*[T](fv: FutureVar[T]): var T =
  ## FutureVarから変数への参照を取得します
  let future = Future[T](fv)
  if not future.finished:
    raise newException(AsyncError, "FutureVar not finished")
  
  if future.error != nil:
    raise future.error
  
  result = future.value

proc newFutureVar*[T](fromProc: string = "unknown"): FutureVar[T] =
  ## 新しいFutureVarを作成します
  result = FutureVar[T](newFuture[T](fromProc))
  complete(Future[T](result), default(T))

# FutureStream 操作
proc write*[T](fs: FutureStream[T], value: T) =
  ## FutureStreamに値を書き込みます
  fs.future.value.add(value)
  for cb in fs.future.callbacks:
    cb()

proc read*[T](fs: FutureStream[T]): Future[T] =
  ## FutureStreamから値を読み取ります
  result = newFuture[T]("FutureStream.read")
  
  if fs.future.value.len > 0:
    let value = fs.future.value[0]
    fs.future.value.delete(0)
    complete(result, value)
  else:
    proc cb() =
      if fs.future.value.len > 0:
        let value = fs.future.value[0]
        fs.future.value.delete(0)
        if not result.finished:
          complete(result, value)
    
    if fs.finished and fs.future.value.len == 0:
      complete(result, default(T))
    else:
      fs.future.callback(cb)

# ================================================================================
# JS / WASM 操作
# ================================================================================

when defined(js):
  ## JavaScriptでの非同期対応
  import jsffi

  proc handleSleep*(callback: proc(wakeUp: proc())) {.importjs: "Asyncify.handleSleep(#)".}
  proc handleAsync*[T](asyncFunc: proc(): T): T {.importjs: "Asyncify.handleAsync(#)".}
  proc callSoon*(cbproc: proc() {.closure, gcsafe.}) =
    ## プロシージャをすぐに実行するためにスケジュールします
    getGlobalDispatcher().callbacks.add(cbproc)

  template sleepAsync*(ms: int): Future[void] =
    ## 非同期でスリープします
    let fut = newFuture[void]("sleepAsync")
    discard handleAsync(proc(): void =
      {.emit: """
      return new Promise((resolve) => {
        setTimeout(() => { resolve(); }, `ms`);
      });
      """.}
    )
    complete(fut)
    fut

else:
  ## WASM環境での非同期対応
  # 未サポートの場合のダミー実装
  proc callSoon*(cbproc: proc() {.closure, gcsafe.}) =
    cbproc() # 非同期でないので即座に実行

  template sleepAsync*(ms: int): Future[void] =
    ## 非同期スリープのWASM実装（ダミー実装）
    let fut = newFuture[void]("sleepAsync")
    # 実際の実装では適切な非同期処理が必要
    complete(fut)
    fut

# ================================================================================
# イベントループ処理
# ================================================================================

proc poll*(timeout = 500) =
  ## イベントループを一回ポーリングします
  let disp = getGlobalDispatcher()
  
  if disp.callbacks.len > 0:
    let cb = disp.callbacks[0]
    disp.callbacks.delete(0)
    cb()
    return

  # タイムアウト処理
  if timeout > 0:
    # ここでブラウザのイベントループに制御を戻す処理を行う
    when defined(js):
      discard sleepAsync(timeout)

proc drain*(timeout = 500) =
  ## 全てのイベントを処理します
  while hasPendingOperations():
    poll(timeout)

proc hasPendingOperations*(): bool =
  ## 未処理の操作があるかどうかをチェックします
  getGlobalDispatcher().callbacks.len > 0

proc runForever*() =
  ## イベントループを永久に実行します
  while true:
    if hasPendingOperations():
      poll()
    else:
      poll(500)

proc waitFor*[T](fut: Future[T]): T =
  ## 指定したFutureが完了するまで待機します
  ## WASMではこれはブロッキングになる可能性があります
  while not fut.finished:
    if hasPendingOperations():
      poll()
    else:
      poll(500)

  result = fut.read()

# ================================================================================
# WASM専用処理
# ================================================================================

proc withTimeout*[T](fut: Future[T], timeout: int): Future[bool] =
  ## タイムアウト付きで非同期処理を実行します
  ## 結果のFutureは処理が完了した場合はtrue、タイムアウトした場合はfalseを返します
  var resultFut = newFuture[bool]("asyncWasm.withTimeout")
  var timeoutFut = sleepAsync(timeout)
  
  proc checkTimeout() =
    if not fut.finished:
      # タイムアウト発生
      complete(resultFut, false)
  
  proc checkResult() =
    if not timeoutFut.finished:
      # 結果が先に来た
      complete(resultFut, true)
  
  timeoutFut.callback(checkTimeout)
  fut.callback(checkResult)
  
  return resultFut

# ================================================================================
# マクロ定義
# ================================================================================

proc identWithParams(n: NimNode): NimNode =
  # ノードと引数を処理するヘルパー
  result = n
  if n.kind == nnkPostfix:
    result = n[1]
  if n.kind == nnkProcDef:
    result = n[0]
  if n.kind == nnkSym:
    result = n
  if n.kind == nnkIdent:
    result = n

proc asyncTransform(prc: NimNode): NimNode =
  ## asyncマクロの内部実装
  prc.expectKind(nnkProcDef)
  
  # 戻り値の型を確認し、必要に応じてFuture[T]に変換
  var returnType = prc[3][0]
  var futureType: NimNode
  
  if returnType.kind == nnkEmpty:
    futureType = nnkBracketExpr.newTree(
      newIdentNode("Future"),
      newIdentNode("void")
    )
  else:
    futureType = nnkBracketExpr.newTree(
      newIdentNode("Future"),
      returnType
    )
  
  prc[3][0] = futureType

  # プロシージャの名前を取得
  let procName = prc[0]
  
  # 非同期プロシージャの本体を作成
  var procBody = prc[6]
  
  # 戻り値のFutureを生成
  let resultIdent = genSym(nskVar, "resultFut")
  let futureVarStmt = quote do:
    var `resultIdent` = newFuture[`returnType`](`procName`.strVal)
  
  # 新しい関数本体を構築
  var newProcBody = newStmtList()
  newProcBody.add(futureVarStmt)
  
  # 元の関数本体を追加（awaitの処理は別途必要）
  newProcBody.add(procBody)
  
  # return resultIdentを追加
  newProcBody.add(quote do:
    return `resultIdent`
  )
  
  # 新しい関数本体をセット
  prc[6] = newProcBody
  
  # {.async.}プラグマを追加
  prc.addPragma(newIdentNode("async"))
  
  result = prc

macro async*(prc: untyped): untyped =
  ## 非同期関数を定義するためのマクロ
  ## ```
  ## proc foo(): int {.async.} =
  ##   result = 42
  ## ```
  result = asyncTransform(prc)

template await*[T](f: Future[T]): untyped =
  ## 非同期処理の結果を待機します
  ## ```
  ## let x = await foo()
  ## ```
  when defined(js):
    # JSモードではasyncifyを使用
    when not compiles(f.injectAwait):
      waitFor(f)
    else:
      f.injectAwait
  else:
    # その他の場合は単にwaitForを使用
    waitFor(f)

macro multisync*(prc: untyped): untyped =
  ## 同期・非同期両方のバージョンの関数を生成するマクロ
  result = newStmtList()
  result.add(asyncTransform(prc.copyNimTree()))

# グローバルディスパッチャを初期化
discard getGlobalDispatcher()
