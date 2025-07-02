# awaitマクロ設計書

## 1. 概要

Nimの`async`/`await`構文風のマクロを実装し、**手続き型で書かれたコードをコールバック関数に自動変換**する。

このマクロは、ICPキャニスターでのコールバック関数を使った非同期呼び出しを、手続き型の直線的なコードとして記述できるようにする**シンタックスシュガー**である。実装は`src/asyncwasm/asyncdipatch.nim`で提供する。

**重要な制限**: 本実装は完全な非同期処理システムではなく、あくまで**コード記述の利便性向上**を目的とする。処理の一時停止、IOブロッキング待機、実行の再開といった本格的な非同期機能は含まない。

## 2. 背景と設計方針

### 2.1. 問題意識

ICPキャニスターでの他キャニスター呼び出しは、必然的にコールバック関数を使った記述になる：

```nim
# 従来の書き方（コールバック地獄）
proc onReply1(env: uint32) {.exportc.} =
  # 第1回応答処理
  callCanister2(args2, onReply2, onReject2)

proc onReply2(env: uint32) {.exportc.} =
  # 第2回応答処理  
  callCanister3(args3, onReply3, onReject3)

proc onReply3(env: uint32) {.exportc.} =
  # 最終処理
  ic0_msg_reply()
```

このような複数の連続するコールバックは、コードの可読性と保守性を著しく損なう。

### 2.2. 解決方針

`await`マクロにより、上記のコードを以下のように記述できるようにする：

```nim
import asyncwasm/asyncdipatch

# 目標とする書き方
proc handler() {.update, async.} =
  try:
    let result1 = await callCanister1(args1)
    let result2 = await callCanister2(args2) 
    let result3 = await callCanister3(args3)
    reply(result3)
  except CatchableError as e:
    reject("An error occurred: " & e.msg)
```

マクロが自動的にコールバック関数を生成し、手続き型の記述を実現する。

### 2.3. 設計目標とICP環境における制約

本実装は、`async_await_in_nim.md`で解説されているNim標準の`async`/`await`機構を参考に、Futureとイテレータをベースとした非同期処理モデルの実現を目的とする。

ただし、ICPのWASM環境には独自の制約があるため、以下の点を考慮する：

- ❗ **受動的ディスパッチモデル**: ICPキャニスターは、OSのスレッドやI/Oイベントを能動的にポーリングし続けるイベントループを実装できない。すべての非同期処理は、ICからのメッセージ（応答コールバック）をトリガーとする**受動的なディスパッチモデル**で動作する必要がある。
- ❗ **`await`は実行中断**: 外部キャニスターを呼び出す`await`は、ICの実行モデル上、現在の関数の実行を中断・終了し、ICに応答を待つよう指示することを意味する。応答が返ってきた際に、ICシステムが指定されたコールバック関数を呼び出すことで、処理が再開される。

## 3. 実装設計

### 3.1. Future型

非同期処理の結果を管理するため、Nim標準ライブラリの `std/asyncfutures` が提供する `Future[T]` 型を全面的に採用する。これにより、標準ライブラリとの互換性を確保する。

`Future[T]`は以下の主要なフィールドを持つ参照オブジェクトである：
*   `value: T`: 成功時の結果を保持する値。
*   `finished: bool`: Futureが完了したか（成功または失敗）を示すフラグ。
*   `error: ref Exception`: 失敗時の例外オブジェクト。
*   `callbacks: seq[proc(future: Future[T])]`: Future完了時に呼び出されるコールバック関数のリスト。`await`の継続処理はここに登録される。

### 3.2. `async`マクロ

Nim標準の`std/asyncmacro`に倣い、`{.async.}`プラグマを処理する`async`マクロを実装する。このマクロは、プロシージャの本体（AST）を解析し、`await`キーワードを持つ箇所で処理を中断・再開できる**クロージャ・イテレータ**に変換する。

```nim
# async_await_in_nim.md で解説されている変換方針
macro async(prc: untyped): untyped =
  # プロシージャをクロージャ・イテレータに変換するコードを生成
```

### 3.3. `await`テンプレートの動作

`await`は、`Future[T]`を引数にとるテンプレートとして実装する。`{.async.}`で変換されたイテレータ内では、`await`は`yield`文に展開される。これにより、指定されたFutureが完了するまでイテレータの実行を中断する。

#### 変換例

`async_await_in_nim.md`で示されているように、マクロは同期的に見えるコードを非同期実行可能なイテレータに変換する。

```nim
# ユーザーが書くコード
proc example(): Future[string] {.async.} =
  echo "Before call"
  let result = await callOtherCanister("test") # これはFuture[string]を返す
  echo "After call: ", result
  return "done"

# asyncマクロが生成するコード（概念）
iterator exampleIter(): FutureBase {.closure.} =
  echo "Before call"
  let future = callOtherCanister("test")
  yield future # futureが完了するまで中断
  let result = future.read()
  echo "After call: ", result
  # 完了したFutureを返すヘルパーを介して最終結果を返す
  return newCompletedFuture("done") 

proc example(): Future[string] =
  # イテレータを駆動し、最終的なFutureを返すヘルパー関数
  return iterToFuture(exampleIter())
```
この`iterToFuture`のようなヘルパー関数が、イテレータをステップ実行し、`yield`されたFutureの完了を待ち、次のステップに進める役割を担う。これがICP環境における**受動的ディスパッチャ**の中核となる。

### 3.4. 標準ライブラリとの整合性

[Nim標準の`std/asyncmacro`](https://nim-lang.org/docs/asyncmacro.html#18)との互換性を可能な限り保つことで、Nim開発者にとって直感的なAPIを目指す。

## 4. 実装予定API

### 4.1. 基本マクロ・テンプレート

```nim
# asyncマクロ - プロシージャを非同期変換
macro async*(prc: untyped): untyped

# awaitテンプレート - Futureの完了を待機
template await*[T](f: Future[T]): T

# エラーハンドリング用テンプレート
template reject*(message: string)
template reply*[T](value: T)
```

### 4.2. サポート関数

```nim
# ICPキャニスター呼び出し用ヘルパー（Futureを返す）
proc callCanister*[T](canister_id: Principal, method: string, 
                     args: seq[byte]): Future[T]
```

## 5. 利用例

### 5.1. 基本的な使用パターン

```nim
import asyncwasm/asyncdipatch

proc getUserData() {.update, async.} =
  try:
    let userData = await getUserCanister.getUser(userId)
    reply(userData)
  except CatchableError as e:
    reject("Failed to get user data: " & e.msg)
```

### 5.2. 複数の呼び出し

```nim
proc processOrder() {.update, async.} =
  try:
    let user = await userCanister.getUser(userId)
    let inventory = await inventoryCanister.checkStock(productId)
    
    if inventory.available:
      let order = await orderCanister.createOrder(user, productId)
      reply(order)
    else:
      reject("Out of stock")
  except CatchableError as e:
    reject("Order processing failed: " & e.msg)
```

### 5.3. エラーハンドリング

`try/except`構文が自然に利用できる。非同期処理で発生した例外は`await`呼び出し元で捕捉可能。

```nim
proc robustCall() {.update, async.} =
  try:
    let result = await riskyCanister.process(data)
    reply(result)
  except CatchableError as e:
    reject("Processing failed: " & e.msg)
```

## 6. 制限事項

### 6.1. 機能的制限

- **受動的実行のみ**: 実行の再開はICからのコールバックに依存
- **シーケンシャル実行**: `await`は直列実行。並行実行 (`waitFor all(@[fut1, fut2])`) のサポートは将来的な課題。

### 6.2. 構文制限

- **`{.async.}`プロシージャ内のみ**: `await`は`{.async.}`で変換されたプロシージャ内でのみ使用可能。

### 6.3. デバッグ制限

- **スタックトレース**: マクロ展開後のスタックトレースは元コードと対応しない
- **エラー行番号**: エラー発生箇所の特定が困難な場合がある

## 7. 実装例：管理キャニスター呼び出し

### 7.1. 従来の実装（コールバック形式）

```nim
# コールバック関数を事前定義
proc onECDSAReply(env: uint32) {.exportc.} =
  let size = ic0_msg_arg_data_size()
  var buf = newSeq[uint8](size)
  ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
  let result = decodeCandid[EcdsaPublicKeyResult](buf)
  reply(result)

proc onECDSAReject(env: uint32) {.exportc.} =
  reject("ECDSA call failed")

proc getPublicKey() {.update.} =
  let args = EcdsaPublicKeyArgs(...)
  callManagementCanister("ecdsa_public_key", encodeCandid(args),
                        onECDSAReply, onECDSAReject)
```

### 7.2. await マクロを使った実装

```nim
import asyncwasm/asyncdipatch
import nicp_cdk/canisters/management_canister

proc getPublicKey() {.update, async.} =
  let args = EcdsaPublicKeyArgs(...)
  try:
    # publicKeyはFuture[EcdsaPublicKeyResult]を返す
    let result = await asyncManagementCanister.publicKey(args)
    reply(result)
  except CatchableError as e:
    reject("ECDSA call failed: " & e.msg)
```

## 8. プロジェクト構成

### 8.1. ファイル構成

本実装は以下のファイル構成で提供される：

#### 非同期処理のための型・関数・プラグマ定義
**`src/asyncwasm/asyncdipatch.nim`**
```nim
# 基本マクロとテンプレートの定義（Nim標準asyncmacroに準拠）
macro async*(prc: untyped): untyped
template await*[T](f: Future[T]): T
template reject*(message: string)
template reply*[T](value: T)

# `std/asyncfutures` を利用
import std/asyncfutures
```

#### 非同期化した外部キャニスターの呼び出し
**`src/nicp_cdk/canisters/management_canister.nim`**
```nim
import std/options
import std/asyncfutures
import ../ic_types/ic_principal
import ../ic_types/candid_types
import ../ic0/ic0
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode

type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs): Future[EcdsaPublicKeyResult] =
  # 1. 結果を格納するための新しいFutureを生成
  result = newFuture[EcdsaPublicKeyResult]("publicKey")

  # 2. ICコールバック内でFutureを完了させるためのラッパープロシージャを定義
  proc onReplyWrapper(env: uint32) {.exportc.} =
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    # Candidメッセージをデコードして結果を取得
    let decoded = decodeCandidMessage(buf) 
    let publicKeyResult = candidValueToEcdsaPublicKeyResult(decoded.values[0])
    
    # 成功した場合はFutureを完了させる
    result.complete(publicKeyResult)

  proc onRejectWrapper(env: uint32) {.exportc.} =
    let err_size = ic0_msg_arg_data_size()
    var err_buf = newSeq[uint8](err_size)
    ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
    let msg = "call failed: " & $err_buf
    # 失敗した場合はFutureを失敗させる
    result.fail(newException(Defect, msg))

  # 3. IC0 API呼び出し処理
  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen = mgmtPrincipalBytes.len
  let methodName = "ecdsa_public_key".cstring
  
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onReplyWrapper),
    reply_env = 0,
    reject_fun = cast[int](onRejectWrapper),
    reject_env = 0
  )

  # ... (引数添付と実行)
  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  
  let err = ic0_call_perform()
  if err != 0:
    result.fail(newException(Defect, "call_perform failed with code: " & $err))

let asyncManagementCanister* = ManagementCanister()
```

#### キャニスターのエントリポイント
**`examples/async_t_ecdsa/src/async_t_ecdsa_backend/main.nim`**
```nim
import std/options
import std/asyncfutures
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister

proc getPublicKey() {.update, async.} =
  let arg = EcdsaPublicKeyArgs(
    canister_id: some(Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai")),
    derivation_path: @[Msg.caller().bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  try:
    let result = await asyncManagementCanister.publicKey(arg)
    reply(result)
  except CatchableError as e:
    trap("Failed to get public key: " & e.msg)
```

### 8.2. 動作確認手順

#### 8.2.1. デプロイメント

```bash
cd /application/examples/async_t_ecdsa
dfx deploy -y
```

#### 8.2.2. 機能テスト

```bash
dfx canister call async_t_ecdsa getPublicKey
```

#### 8.2.3. 期待される出力

正常に動作する場合、ECDSA公開鍵が返される：

```
(
  record {
    public_key = blob "\04\XX\XX...";  # 公開鍵のバイト列
    chain_code = blob "\XX\XX...";     # チェーンコード
  }
)
```

## 9. 実装戦略

### 9.1. 段階的実装

1. **フェーズ1**: 基本的な`await`マクロの実装
2. **フェーズ2**: エラーハンドリングの追加
3. **フェーズ3**: 複雑な制御フローへの対応

### 9.2. テスト戦略

- **単体テスト**: マクロ展開結果の検証
- **統合テスト**: 実際のキャニスター呼び出しでの動作確認
- **エラーケース**: 異常系での適切なエラーハンドリング確認

この設計により、ICPキャニスター開発での**コールバック地獄**を解消し、Nimの標準的な非同期処理に近い、より読みやすく保守しやすいコードの記述を可能にする。
