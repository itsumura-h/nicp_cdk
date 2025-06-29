# awaitマクロ設計書

## 1. 概要

NimでWASM上で非同期処理を擬似的に実現するため、`await`キーワードを使用した構文を、コールバックベースの非同期処理コードに変換するマクロを設計する。

これにより、開発者は同期処理に近い感覚で非同期コードを記述できる一方、実行時にはWASMの制約に対応したコールバック形式のコードとして動作させることができる。

## 2. 背景

現状のWASM環境では、Nimの標準的な非同期処理（`async`/`await`）が完全にはサポートされていない。しかし、JavaScriptとの連携などで非同期処理の必要性は高い。

そこで、Nimの強力なメタプログラミング機能であるマクロを利用し、`await`構文をコンパイル時に`Future.then`を用いたコールバックチェーンに展開する仕組みを構築する。

## 3. 設計方針

### 3.1. `await`の変換

`await`を含む式を解析し、`await`の対象となる非同期関数呼び出しと、その後の処理を分離するマクロを実装する。

**変換前:**

```nim
proc asyncFunc(): Future[string] =
  await sleepAsync(1000)
  return "Hello, World!"

proc main() =
  let result = await asyncFunc()
  echo result
```

**変換後:**

```nim
proc asyncFunc(): Future[string] =
  return sleepAsync(1000).then(proc(result: void): Future[string] =
    return "Hello, World!"
  )

proc main() =
  asyncFunc().then(proc(result: string) =
    echo result
  )
```

### 3.2. マクロの実装

`await`キーワードをトリガーとするマクロを定義する。このマクロは、`await`が適用された式のAST（抽象構文木）を受け取り、それを`then`メソッド呼び出しのASTに変換して返す。

- **`await`がプロシージャ本体の文として使われる場合:**
  - `await`の後の文をすべて取得し、それらを`then`に渡すコールバックプロシージャの本体に移動する。
  - `await`の対象となる`Future`の型引数を解決し、コールバックプロシージャの引数として渡す。
- **`await`が式の一部として使われる場合（例: `let x = await y()`）:**
  - `await`を含む文を分割する。
  - `y()`の呼び出しと`then`のチェーンを生成する。
  - `then`のコールバック内で、結果を`x`に代入し、元の文の残りの部分を実行する。

### 3.3. `Future`オブジェクト

このマクロは、`then`メソッドを持つ`Future`オブジェクトが定義されていることを前提とする。`Future`は以下のようなインターフェースを持つ必要がある。

```nim
type Future[T] = object
  # ... 内部状態

proc then[T, U](future: Future[T], callback: proc(val: T): Future[U]): Future[U]
proc then[T](future: Future[T], callback: proc(val: T))
```

## 4. 実装の詳細

マクロは`macros`モジュールを使い、NimのASTを操作する。

1.  **`await`マクロの定義:**
    `macro await(call: untyped): untyped` のようなシグネチャでマクロを定義する。

2.  **ASTの解析:**
    `call`パラメータは`await`の後の式を表すASTノード。
    - `call`が代入文（`nkAsgn`）か、単なる式文（`nkExprStmt`）かを判断する。
    - `await`の対象となる非同期呼び出し（例: `asyncFunc()`）と、その後の処理をASTレベルで分離する。

3.  **ASTの再構築:**
    - `newCall`を使って`then`メソッド呼び出しのASTを構築する。
    - `newProc`を使ってコールバック関数のASTを生成する。
    - 元の式の後続の文を、生成したコールバックプロシージャの本体に移動させる。

4.  **型情報の扱い:**
    非同期関数の戻り値の型（`Future[T]`の`T`）を正しく解決し、コールバックの引数に設定する必要がある。`getType`などのマクロAPIを利用する。

## 5. 利用例

### 5.1. `await`を文として利用

```nim
# 変換前
proc example() =
  echo "Waiting..."
  await sleepAsync(1000)
  echo "Done."

# 変換後
proc example() =
  echo "Waiting..."
  sleepAsync(1000).then(proc() =
    echo "Done."
  )
```

### 5.2. `await`を式として利用

```nim
# 変換前
proc example() =
  let message = await fetchMessage()
  echo "Message is: ", message

# 変換後
proc example() =
  fetchMessage().then(proc(message: string) =
    echo "Message is: ", message
  )
```

## 6. 制限事項

-   ループや例外処理ブロック（`try`/`except`）内での`await`の使用は、単純な変換では困難な場合がある。これらのケースでは、より複雑なAST変換が必要になるか、あるいは使用を制限する必要があるかもしれない。
-   `await`はプロシージャのトップレベルの文、もしくは単純な代入文でのみサポートされる、といった制約を設けることで、実装を簡略化できる。

以上
