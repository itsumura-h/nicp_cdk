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
# 目標とする書き方
proc handler() {.update.} = async:
  let result1 = await callCanister1(args1)
  let result2 = await callCanister2(args2) 
  let result3 = await callCanister3(args3)
  reply(result3)
```

マクロが自動的にコールバック関数を生成し、手続き型の記述を実現する。

### 2.3. 非同期処理ではないことの明確化

本実装は以下を**含まない**：

- ❌ **処理の一時停止**: 実行コンテキストの保存や復元
- ❌ **IOブロッキング待機**: ネットワークやファイルI/Oの完了待ち
- ❌ **イベントループ**: タスクスケジューリングやディスパッチ
- ❌ **並行実行**: 複数タスクの同時実行管理
- ❌ **本格的なFuture型**: 状態管理やWaker機構

✅ **含むもの**: 手続き型コードのコールバック変換のみ

## 3. 実装設計

### 3.1. 簡略化されたFuture型

本格的なFuture実装ではなく、コールバック管理のための最小限の型を定義：

```nim
type
  FutureCallback[T] = ref object
    onSuccess: proc(value: T)
    onError: proc(error: string)
    completed: bool
    result: T
    errorMsg: string
```

### 3.2. `async`マクロ

Nim標準の`std/asyncmacro`に倣い、`async`を**マクロ**として実装する。このマクロはプロシージャを解析し、非同期風の記述を可能にするコード変換を行う：

```nim
macro async(prc: untyped): untyped =
  # プロシージャを解析してコールバック変換コードを生成
  # awaitキーワードを含む処理を適切に変換
```

使用方法（プラグマとして呼び出し）：
```nim
proc handler() {.update, async.} =
  # awaitが使用可能になる
  let result = await callCanister("test")
  reply(result)
```

### 3.3. `await`テンプレートの動作

Nim標準の実装に倣い、`await`を**テンプレート**として実装する。テンプレートは以下の変換を行う：

```nim
template await[T](f: typed): auto =
  # コールバック登録とコードの継続処理
  # 実際の型チェックと変換はコンパイル時に実行
```

#### 変換処理の詳細

1. **型の解析**: `await`に渡された式の型を解析
2. **継続の生成**: `await`以降のコードをテンプレート展開で継続として抽出
3. **コールバック登録**: 生成された継続をコールバックとして登録
4. **実行制御**: 現在の実行を適切に終了

#### 変換例

```nim
# ユーザーが書くコード
proc example() {.update, async.} =
  echo "Before call"
  let result = await callOtherCanister("test")
  echo "After call: ", result
  reply("done")

# async マクロとawait テンプレートが生成するコード（概念）
proc example() {.update.} =
  echo "Before call"
  
  proc continuation(result: string) =
    echo "After call: ", result
    reply("done")
  
  proc errorHandler(error: string) =
    reject(error)
  
  callOtherCanister("test", continuation, errorHandler)
  return  # ここで現在の実行終了
```

### 3.4. 標準ライブラリとの整合性

[Nim標準の`std/asyncmacro`](https://nim-lang.org/docs/asyncmacro.html#18)との整合性を保つため：

- **`async`マクロ**: `macro async(prc: untyped): untyped`として実装
- **`await`テンプレート**: `template await[T](f: Future[T]): auto`として実装
- **Future型**: 標準の`asyncfutures`モジュールとの互換性を考慮

## 4. 実装予定API

### 4.1. 基本マクロ・テンプレート

```nim
# asyncマクロ - プロシージャを非同期変換
macro async*(prc: untyped): untyped

# awaitテンプレート - 非同期呼び出しの待機
template await*[T](f: typed): auto

# エラーハンドリング用テンプレート
template reject*(message: string)
template reply*[T](value: T)
```

### 4.2. サポート関数

```nim
# ICPキャニスター呼び出し用ヘルパー
proc callCanister*[T](canister_id: Principal, method: string, 
                     args: seq[byte], 
                     onSuccess: proc(result: T),
                     onError: proc(error: string))
```

## 5. 利用例

### 5.1. 基本的な使用パターン

```nim
import asyncwasm/asyncdipatch

proc getUserData() {.update, async.} =
  let userData = await getUserCanister.getUser(userId)
  reply(userData)
```

### 5.2. 複数の呼び出し

```nim
proc processOrder() {.update, async.} =
  let user = await userCanister.getUser(userId)
  let inventory = await inventoryCanister.checkStock(productId)
  
  if inventory.available:
    let order = await orderCanister.createOrder(user, productId)
    reply(order)
  else:
    reject("Out of stock")
```

### 5.3. エラーハンドリング

```nim
proc robustCall() {.update, async.} =
  try:
    let result = await riskyCanister.process(data)
    reply(result)
  except:
    reject("Processing failed")
```

## 6. 制限事項

### 6.1. 機能的制限

- **真の非同期処理ではない**: 実行の一時停止・再開は行わない
- **シーケンシャル実行のみ**: 並行実行や並列処理は非サポート
- **単純なコールバック変換**: 複雑な制御フローは対応困難

### 6.2. 構文制限

- **`async`マクロ使用プロシージャ内のみ**: `await`は`async`マクロで変換されたプロシージャ内でのみ使用可能
- **単一戻り値**: 複数の戻り値やタプルの直接サポートなし
- **ネストした`await`**: `await`のネストには制限あり

### 6.3. デバッグ制限

- **スタックトレース**: マクロ展開後のスタックトレースは元コードと対応しない
- **エラー行番号**: エラー発生箇所の特定が困難な場合がある

## 7. 実装例：管理キャニスター呼び出し

### 7.1. 従来の実装

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

proc getPublicKey() {.update, async.} =
  let args = EcdsaPublicKeyArgs(...)
  let result = await callManagementCanister("ecdsa_public_key", encodeCandid(args))
  reply(result)
```

## 8. プロジェクト構成

### 8.1. ファイル構成

本実装は以下のファイル構成で提供される：

#### 非同期処理のための型・関数・プラグマ定義
**`src/asyncwasm/asyncdipatch.nim`**
```nim
# 基本マクロとテンプレートの定義（Nim標準asyncmacroに準拠）
macro async*(prc: untyped): untyped
template await*[T](f: typed): auto
template reject*(message: string)
template reply*[T](value: T)

# コールバック管理用の最小限の型
type
  FutureCallback[T] = ref object
    onSuccess: proc(value: T)
    onError: proc(error: string)
    completed: bool
    result: T
    errorMsg: string
```

#### 非同期化した外部キャニスターの呼び出し
**`src/nicp_cdk/canisters/async_management_canister.nim`**
```nim
import std/options
import std/asyncfutures
import ../ic_types/ic_principal
import ../ic_types/candid_types
import ../ic0/ic0
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode

type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs, 
                onReply: proc(result: EcdsaPublicKeyResult), 
                onReject: proc(error: string)) =
  proc onReplyWrapper(env: uint32) {.exportc.} =
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let result = decodeCandidMessage(buf, EcdsaPublicKeyResult)
    onReply(result)

  proc onRejectWrapper(env: uint32) {.exportc.} =
    let err_size = ic0_msg_arg_data_size()
    var err_buf = newSeq[uint8](err_size)
    ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
    let msg = "call failed: " & $err_buf
    onReject(msg)

  # IC0 API呼び出し処理
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

  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  
  let err = ic0_call_perform()
  if err != 0:
    onReject("call_perform failed")

let asyncManagementCanister* = ManagementCanister()
```

#### キャニスターのエントリポイント
**`examples/async_t_ecdsa/src/async_t_ecdsa_backend/main.nim`**
```nim
import std/options
import std/asyncfutures
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/async_management_canister

proc getPublicKey() {.update, async.} =
  let arg = EcdsaPublicKeyArgs(
    canister_id: Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai").some(),
    derivation_path: @[Msg.caller().bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  asyncManagementCanister.publicKey(
    arg,
    proc(result: EcdsaPublicKeyResult) =
      reply(result)
    ,
    proc(error: string) =
      trap(error)
  )
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

この設計により、ICPキャニスター開発での**コールバック地獄**を解消し、より読みやすく保守しやすいコードの記述を可能にする。完全な非同期処理システムではないが、実用的なコード記述支援ツールとして機能する。
