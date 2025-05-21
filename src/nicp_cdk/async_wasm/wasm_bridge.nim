## wasm_bridge module
## =============
##
## WASMとJavaScriptの間のブリッジを提供するモジュールです。
## このモジュールはWASMバイナリをコンパイルする際にJavaScriptグルーコードを生成します。

import macros
import async_wasm

when defined(js):
  import jsffi
  import jsconsole

# JavaScript側で定義されたAsyncify関数をインポート
when defined(js):
  # JSからエクスポートされるグローバル変数
  var global {.importc, nodecl.}: JsObject

  # Asyncifyのインターフェース
  type Asyncify* = object
    handleSleep*: proc(callback: proc(wakeUp: proc())) {.closure.}
    handleAsync*: proc(asyncFunc: proc(): JsObject) {.closure.}
    start_unwind*: proc(address: int) {.closure.}
    stop_unwind*: proc() {.closure.}
    start_rewind*: proc(address: int) {.closure.}
    stop_rewind*: proc() {.closure.}

  # AsyncifyオブジェクトをJSから取得
  var asyncify* {.importc, nodecl.}: Asyncify

# JavaScriptからの非同期関数呼び出しをサポートするマクロ
macro exportAsync*(procDef: untyped): untyped =
  ## JavaScript側から呼び出せる非同期関数をエクスポートします
  ## 通常の戻り値はPromiseにラップされます
  ##
  ## 例:
  ## ```nim
  ## proc fetchData(url: cstring): int {.exportAsync.} =
  ##   # 非同期処理
  ##   result = 42
  ## ```
  ##
  ## JavaScriptからは以下のように呼び出せます:
  ## ```javascript
  ## Module.fetchData("https://example.com").then(result => {
  ##   console.log(result); // 42
  ## });
  ## ```
  result = procDef.copyNimTree()
  
  # exportcプラグマを追加
  result.addPragma(newIdentNode("exportc"))
  
  # asyncプラグマを追加
  result.addPragma(newIdentNode("async"))

# ==============================
# WASM環境のための便利な関数
# ==============================

when defined(js):
  # JavaScriptから非同期関数を呼び出す
  proc callJsAsync*[T](fn: proc(): Future[T]): Future[T] {.async.} =
    ## JavaScriptの非同期関数をNimから呼び出します
    result = await fn()

  # setTimeout実装
  proc setTimeout*(ms: int): Future[void] {.async.} =
    ## JavaScriptのsetTimeoutをラップした非同期スリープ関数
    discard asyncify.handleAsync(proc(): JsObject =
      {.emit: """
      return new Promise((resolve) => {
        setTimeout(resolve, `ms`);
      });
      """.}
    )

  # fetch実装
  proc fetch*(url: cstring): Future[cstring] {.async.} =
    ## JavaScriptのFetch APIをラップした関数
    let response = asyncify.handleAsync(proc(): JsObject =
      {.emit: """
      return fetch(`url`).then(response => response.text());
      """.}
    )
    result = cast[cstring](response)

# WASM環境の初期化
proc initWasmAsync*() =
  ## WASM非同期環境を初期化します
  ## WASMモジュールの初期化時に呼び出す必要があります
  when defined(js):
    # Asyncifyが利用可能かチェック
    {.emit: """
    if (typeof Asyncify === 'undefined') {
      console.error("Asyncify is not available. Please compile with -s ASYNCIFY=1");
    }
    """.}
    console.log("WASM async environment initialized")
  else:
    echo "WASM async environment initialized (dummy)"

# サンプル関数（テスト用）
when defined(js) and isMainModule:
  # エクスポートする非同期関数の例
  proc exampleAsyncFunction*(input: cstring): Future[cstring] {.exportAsync.} =
    echo "Called with: ", input
    await setTimeout(1000)
    result = "Processed: " & $input

  # モジュール初期化
  initWasmAsync() 
