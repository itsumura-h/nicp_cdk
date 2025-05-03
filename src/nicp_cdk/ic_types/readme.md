IC Types
===

ICPで扱う型を保持する。

次の関数をそれぞれ実装する
- リクエストのバイト列から値を取得するreadXx関数（candid.nimで呼ばれる）
  - `(data:seq[byte], offset:var int) -> T`
- 値をレスポンス用のバイト列に変換するserializeCandid関数（candid.nimで呼ばれる）
  - `(value:T) -> seq[byte]`
- 値を文字列に変換する`$`関数
  - `(value:T) -> string`

**ic0はimportしない**
