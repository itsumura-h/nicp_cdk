# Nim WASM非同期処理実装方針

このドキュメントは、RustとMotokoの非同期処理実装調査結果に基づき、NimでWASM（特にInternet Computer）向けの非同期処理ライブラリを実装するための設計方針をまとめたものです。

## 1. 概要と目標

### 1.1 実装目標
- **API互換性**: Nim標準`asyncdispatch`と可能な限り同じAPIを提供
- **WASM最適化**: WebAssembly/IC環境に特化した効率的な実装
- **型安全性**: コンパイル時に非同期関連のエラーを検出
- **軽量実装**: Asyncifyに依存しない独自の状態機械実装

### 1.2 対象環境
- **Primary**: Internet Computer (IC) Canister環境
- **Secondary**: WASI (WebAssembly System Interface)
- **考慮外**: ブラウザ環境（別途JS Bridge実装予定）

## 2. アーキテクチャ設計

### 2.1 基本型定義

```nim
# src/asyncwasm/types.nim
type
  # 基本Future型（Rustのstd::future::Futureに相当）
  Future[T] = ref object
    value: T                    # 完了時の結果値
    error: ref Exception        # エラー時の例外
    finished: bool              # 完了フラグ
    callbacks: seq[proc()]      # 完了時コールバック
    state: FutureState          # 内部状態
    
  FutureState = enum
    Pending,      # 実行中
    Completed,    # 正常完了
    Failed        # エラー完了
    
  # エグゼキュータ型
  Executor = ref object
    pendingTasks: seq[Future[void]]         # 実行待ちタスク
    waitingIO: Table[AsyncFD, Future[void]] # I/O待ちタスク
    timers: seq[TimerEntry]                 # タイマータスク
    running: bool                           # 実行中フラグ
    
  TimerEntry = object
    deadline: int64           # 満期時刻（UNIX timestamp ms）
    future: Future[void]      # 対応するFuture
    
  AsyncFD = distinct int      # 非同期ファイルディスクリプタ
```

### 2.2 状態機械ベースの実装戦略

RustのFuture実装を参考に、以下の方針で状態機械を構築：

#### 2.2.1 マクロベースのコード変換
```nim
# コンパイル時にasync関数を状態機械に変換
macro async*(prc: untyped): untyped =
  # プロシージャ本体のASTを解析
  # await呼び出し箇所で状態遷移ポイントを識別
  # iterator + closure環境での状態保存コードを生成
  result = generateStateMachine(prc)
```

#### 2.2.2 実行時状態管理
```nim
# 各async関数は内部的にiteratorとして実装
iterator asyncProcIterator(): T =
  var localVar1: SomeType
  var localVar2: AnotherType
  
  # State 0: 初期状態
  localVar1 = someInitialValue()
  
  # State 1: 最初のawait地点
  yield AwaitPoint(someAsyncCall())
  
  # State 2: await後の継続
  localVar2 = processResult(localVar1)
  
  # State N: 完了
  yield FinalResult(localVar2)
```

### 2.3 エグゼキュータ設計

#### 2.3.1 IC特化型エグゼキュータ
Internet Computer環境に最適化されたシングルタスク実行モデル：

```nim
# src/asyncwasm/ic_executor.nim
type
  ICExecutor = ref object of Executor
    messageContext: ICMessageContext    # ICメッセージコンテキスト
    callbackRegistry: Table[CallId, Future[void]]  # inter-canisterコール管理
    
proc runUntilComplete*(executor: ICExecutor, future: Future[T]): T =
  ## ICメッセージハンドラ内でFutureが完了するまで実行
  while not future.finished:
    case pollIC(executor):
    of ICEvent.IncomingCall:
      handleIncomingCall(executor)
    of ICEvent.CallResponse:
      resumeWaitingCall(executor)
    of ICEvent.Timer:
      processTimers(executor)
    of ICEvent.NoMoreEvents:
      break  # メッセージ処理完了
      
  if future.error != nil:
    raise future.error
  result = future.value
```

#### 2.3.2 WASI汎用エグゼキュータ
WASI環境での汎用的な非同期処理：

```nim
# src/asyncwasm/wasi_executor.nim
type
  WASIExecutor = ref object of Executor
    pollSubscriptions: seq[WASIPollSubscription]
    
proc poll*(executor: WASIExecutor, timeout: Duration): int =
  ## WASI poll_oneoffを使用したイベント待機
  var subscriptions = executor.pollSubscriptions
  var events: array[32, WASIEvent]
  
  let eventCount = wasiPollOneoff(
    addr subscriptions[0], subscriptions.len,
    addr events[0], events.len
  )
  
  for i in 0..<eventCount:
    case events[i].eventType:
    of WASI_EVENTTYPE_FD_READ:
      resumeIOFuture(executor, events[i].fd, IOEvent.Read)
    of WASI_EVENTTYPE_FD_WRITE:
      resumeIOFuture(executor, events[i].fd, IOEvent.Write)
    of WASI_EVENTTYPE_CLOCK:
      processExpiredTimers(executor)
      
  result = eventCount
```

## 3. コア機能実装

### 3.1 await実装
```nim
# src/asyncwasm/await.nim
template await*[T](future: Future[T]): T =
  ## async関数内でのみ使用可能
  when not declared(currentAsyncContext):
    {.error: "await can only be used inside async procedures".}
  
  if not future.finished:
    # 現在のFutureを一時停止し、待機対象に継続を登録
    registerContinuation(future, currentAsyncContext)
    yield PendingState()
    
  # 完了後の処理
  if future.error != nil:
    raise future.error
  future.value
```

### 3.2 基本非同期関数
```nim
# src/asyncwasm/primitives.nim
proc sleepAsync*(ms: int): Future[void] =
  ## 指定時間後に完了するFuture
  result = newFuture[void]()
  let deadline = getTime().toUnixFloat() * 1000 + ms.float
  getGlobalExecutor().addTimer(deadline, result)

proc spawnAsync*[T](asyncProc: proc(): Future[T]): Future[T] =
  ## 非同期タスクをバックグラウンドで開始
  result = asyncProc()
  getGlobalExecutor().addTask(result)

proc waitFor*[T](future: Future[T]): T =
  ## Futureの完了を同期的に待機（メインスレッドでのみ使用）
  let executor = getGlobalExecutor()
  result = executor.runUntilComplete(future)
```

### 3.3 I/O操作
```nim
# src/asyncwasm/io.nim
proc readAsync*(fd: AsyncFD, buffer: ptr UncheckedArray[uint8], length: int): Future[int] =
  ## 非同期読み込み
  result = newFuture[int]()
  
  when defined(ic):
    # IC環境では同期I/Oのみサポート
    try:
      let bytesRead = ic_stable_read(fd.int, buffer, length)
      result.complete(bytesRead)
    except:
      result.fail(getCurrentException())
  else:
    # WASI環境での非同期I/O
    getGlobalExecutor().registerIORead(fd, buffer, length, result)

proc writeAsync*(fd: AsyncFD, buffer: ptr UncheckedArray[uint8], length: int): Future[int] =
  ## 非同期書き込み
  result = newFuture[int]()
  
  when defined(ic):
    try:
      let bytesWritten = ic_stable_write(fd.int, buffer, length)
      result.complete(bytesWritten)
    except:
      result.fail(getCurrentException())
  else:
    getGlobalExecutor().registerIOWrite(fd, buffer, length, result)
```

## 4. IC固有機能

### 4.1 Inter-Canister Call
```nim
# src/asyncwasm/ic_calls.nim
proc callAsync*[T](
  canisterId: Principal, 
  methodName: string,
  args: CandidRecord,
  cycles: int64 = 0
): Future[T] =
  ## 他のCanisterの関数を非同期で呼び出し
  result = newFuture[T]()
  
  let callId = ic_call_new(
    canisterId.toBytes(),
    methodName.cstring,
    serializeCandid(args).cstring,
    cycles
  )
  
  # レスポンス待機の登録
  getICExecutor().registerCall(callId, result)
  
  # 呼び出し実行
  ic_call_perform()

proc updateAsync*[T](methodProc: proc(): Future[T]): Future[T] =
  ## Canister updateメソッドの非同期ラッパー
  result = methodProc()
  
  # IC特有の処理（heartbeat等）を考慮した実行
  getICExecutor().executeInMessageContext(result)
```

### 4.2 タイマーとハートビート
```nim
# src/asyncwasm/ic_timers.nim
proc setGlobalTimer*(duration: Duration, callback: proc()) =
  ## ICグローバルタイマーの設定
  let nanoseconds = duration.inNanoseconds()
  ic_global_timer_set(nanoseconds, cast[pointer](callback))

proc heartbeatAsync*(): Future[void] =
  ## ハートビート処理の非同期化
  result = newFuture[void]()
  
  # 定期的にタスクスケジューリングを実行
  proc heartbeatHandler() =
    let executor = getICExecutor()
    executor.processHeartbeat()
    result.complete()
    
  setGlobalTimer(Duration.fromSeconds(1), heartbeatHandler)
```

## 5. 最適化戦略

### 5.1 コンパイル時最適化
```nim
# マクロでの最適化例
macro optimizeAsync*(body: untyped): untyped =
  # 連続するawaitの結合
  # 不要な状態遷移の除去
  # インライン展開可能な関数の特定
  result = optimizeAsyncAST(body)

# 使用例
proc complexAsyncProc(): Future[int] {.async.} =
  optimizeAsync:
    let a = await simpleCall1()
    let b = await simpleCall2()
    result = a + b
```

### 5.2 メモリ効率化
```nim
# オブジェクトプール使用
type
  FuturePool[T] = object
    available: seq[Future[T]]
    created: int
    
proc borrowFuture*[T](pool: var FuturePool[T]): Future[T] =
  if pool.available.len > 0:
    result = pool.available.pop()
    result.reset()
  else:
    result = Future[T](state: Pending)
    inc pool.created

proc returnFuture*[T](pool: var FuturePool[T], future: Future[T]) =
  pool.available.add(future)
```

### 5.3 コードサイズ最適化
```nim
# テンプレートでの共通コード削減
template commonAsyncSetup*(futureVar: untyped): untyped =
  let executor = getGlobalExecutor()
  futureVar = newFuture[type(futureVar[])]()
  
template commonAsyncCleanup*(futureVar: untyped): untyped =
  if futureVar.error != nil:
    raise futureVar.error
```

## 6. エラー処理とデバッグ

### 6.1 構造化例外処理
```nim
# src/asyncwasm/exceptions.nim
type
  AsyncException* = object of CatchableError
    futureStack*: seq[string]  # 非同期スタックトレース
    
  TimeoutError* = object of AsyncException
  ChannelClosedError* = object of AsyncException
  ICCallError* = object of AsyncException
    callId*: string
    canisterId*: Principal

proc captureAsyncStack(): seq[string] =
  # 現在のasync関数呼び出しスタックを取得
  result = []
  for frame in getCurrentAsyncFrames():
    result.add(frame.procName & ":" & $frame.line)
```

### 6.2 デバッグ支援
```nim
# デバッグモードでの詳細ログ
when defined(asyncDebug):
  template debugAsyncLog*(msg: string) =
    echo "[ASYNC] ", msg, " at ", instantiationInfo()
else:
  template debugAsyncLog*(msg: string) = discard

# パフォーマンス計測
type
  AsyncProfiler* = object
    taskCounts*: Table[string, int]
    totalTimes*: Table[string, float]
    
proc profileAsync*[T](name: string, future: Future[T]): Future[T] =
  when defined(asyncProfile):
    let start = cpuTime()
    result = future
    result.addCallback proc() =
      let elapsed = cpuTime() - start
      getGlobalProfiler().record(name, elapsed)
  else:
    result = future
```

## 7. テスト戦略

### 7.1 単体テスト
```nim
# tests/asyncwasm/test_futures.nim
import unittest
import ../src/asyncwasm

suite "Basic Future Operations":
  test "Future completion":
    proc testProc(): Future[int] {.async.} =
      return 42
      
    let result = waitFor testProc()
    check result == 42
    
  test "Future with await":
    proc asyncAdd(a, b: int): Future[int] {.async.} =
      await sleepAsync(10)  # 10ms待機
      return a + b
      
    let result = waitFor asyncAdd(5, 3)
    check result == 8
```

### 7.2 統合テスト
```nim
# tests/asyncwasm/test_ic_integration.nim
proc testICCall(): Future[string] {.async.} =
  let response = await callAsync[string](
    principal("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    "greet",
    %* {"name": "World"}
  )
  return response

when defined(ic):
  suite "IC Integration Tests":
    test "inter-canister call":
      let result = waitFor testICCall()
      check result.contains("Hello, World")
```

## 8. ドキュメント化とAPI参考資料

### 8.1 API互換性マップ
| Nim標準asyncdispatch | 本実装 | 備考 |
|-------------------|-------|------|
| `asyncCheck` | `spawnAsync` | タスクのバックグラウンド実行 |
| `waitFor` | `waitFor` | 完全互換 |
| `sleepAsync` | `sleepAsync` | 完全互換 |
| `asyncdispatch.runForever` | `runForever` | IC環境では制限あり |

### 8.2 使用例ドキュメント
```nim
# 基本的な使用例
proc example1(): Future[string] {.async.} =
  echo "処理開始"
  await sleepAsync(1000)  # 1秒待機
  return "完了"

# IC固有機能の使用例
proc example2(): Future[void] {.async.} =
  let balance = await callAsync[nat](
    ic.managementCanister,
    "canister_status",
    %* {"canister_id": ic.id()}
  )
  echo "Current cycles: ", balance

# エラーハンドリング例
proc example3(): Future[string] {.async.} =
  try:
    let result = await riskyAsyncOperation()
    return result
  except AsyncException as e:
    echo "Async error: ", e.msg
    echo "Stack: ", e.futureStack
    raise
```

## 9. 実装ロードマップ

### フェーズ1: 基盤実装 (2週間)
- [ ] 基本型定義 (`Future[T]`, `Executor`)
- [ ] マクロベースの`async`/`await`変換
- [ ] シンプルな同期的エグゼキュータ

### フェーズ2: IC統合 (2週間)
- [ ] IC特化型エグゼキュータ
- [ ] Inter-Canister Call機能
- [ ] IC System API統合

### フェーズ3: 最適化とテスト (1週間)
- [ ] パフォーマンス最適化
- [ ] 包括的テストスイート
- [ ] ドキュメント整備

### フェーズ4: 拡張機能 (1週間)
- [ ] WASI対応
- [ ] 高度なエラーハンドリング
- [ ] プロファイリング機能

## 10. まとめ

本実装方針は、RustとMotokoの調査結果を基に、Nimの言語特性を活かしたWASM向け非同期処理ライブラリの設計を提供します。特にInternet Computer環境での高効率な動作を重視し、既存のNim `asyncdispatch` APIとの互換性を保ちながら、WASM特有の制約に対応した実装となっています。

実装完了により、Nimでも他の主要言語と同等の非同期プログラミング体験をWASM環境で提供できるようになります。 