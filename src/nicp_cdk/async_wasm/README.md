# async_wasm モジュール

このモジュールは、NimをWebAssembly環境で動作させる際に非同期処理を可能にするためのライブラリです。Nimの`asyncdispatch`モジュールと同様のインターフェースを提供し、WASMビルド時にEmscriptenのAsyncify機能を活用します。

## 概要

WebAssembly環境では、JavaScriptとは異なり、デフォルトでは非同期処理を行うことができません。このモジュールは、Emscriptenの「Asyncify」技術を使って、同期的に書かれたNimコードを非同期に実行することを可能にします。

## 主な機能

- `asyncdispatch`互換のAPI
- 非同期処理のための`Future`、`async`、`await`のサポート
- JavaScriptの非同期APIとの統合
- WASMからJavaScriptのAPIを非同期に呼び出す機能

## 必要条件

- Nim 1.6.0以上
- WASM向けコンパイル時は、Emscriptenでの`-s ASYNCIFY=1`フラグが必要

## 使い方

### 基本的な使い方

```nim
import async_wasm

proc fetchData(): Future[string] {.async.} =
  # 非同期処理
  await sleepAsync(1000)  # 1秒待機
  result = "データ"

proc main() =
  let data = waitFor fetchData()
  echo data
```

### JavaScriptの非同期APIを使用する

```nim
import async_wasm
import async_wasm/wasm_bridge

proc fetchFromUrl(url: string): Future[string] {.async.} =
  let response = await fetch(url.cstring)
  result = $response

when isMainModule:
  initWasmAsync()  # WASM環境の初期化
  let data = waitFor fetchFromUrl("https://example.com")
  echo data
```

### JavaScriptから呼び出し可能な非同期関数のエクスポート

```nim
import async_wasm
import async_wasm/wasm_bridge

proc processData*(data: cstring): Future[cstring] {.exportAsync.} =
  # 何らかの処理
  await setTimeout(1000)
  result = ("Processed: " & $data).cstring

when isMainModule:
  initWasmAsync()
```

JavaScriptからは以下のように呼び出せます：

```javascript
Module.processData("テストデータ").then(result => {
  console.log(result);  // "Processed: テストデータ"
});
```

## コンパイル方法

### Emscriptenでのコンパイル例

```bash
nim js -d:release -d:emscripten -d:js --out=myapp.js myapp.nim
emcc myapp.js -o myapp.html -s ASYNCIFY=1 -s ASYNCIFY_IMPORTS=['fetch','setTimeout']
```

## 実装の詳細

### 非同期処理のメカニズム

このライブラリは、以下の方法で非同期処理を実現しています：

1. **JS環境**: EmscriptenのAsyncify機能を使用し、非同期処理の間にWASMコードの実行状態を保存・復元します。
2. **Future型**: 非同期処理の結果を表す型として、`asyncdispatch`と同様のFuture型を提供します。
3. **async/awaitマクロ**: 非同期コードを同期的に書けるようにするマクロを提供します。

### モジュール構成

- `async_wasm.nim`: メインモジュール。Future型と非同期操作の基本実装を提供
- `wasm_bridge.nim`: WASMとJavaScriptの間のブリッジ機能
- `example.nim`: サンプルコード

## 制限事項

- WASM環境では、Emscriptenのコンパイル設定で明示的にAsyncifyを有効にする必要があります。
- パフォーマンスにオーバーヘッドがあるため、頻繁に呼び出される関数での使用は避けるべきです。
- 大きな関数の場合、Asyncifyによるコード変換でサイズが増大する可能性があります。

## ライセンス

MITライセンス

## 参考資料

- [Asyncify - Emscripten Documentation](https://emscripten.org/docs/porting/asyncify.html)
- [Nim asyncdispatch module](https://nim-lang.org/docs/asyncdispatch.html)
- [Using asynchronous web APIs from WebAssembly](https://web.dev/articles/asyncify) 
