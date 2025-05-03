https://github.com/dfinity/candid/blob/master/docs/modules/candid-guide/pages/candid-types.adoc

# サポートされている型

このセクションでは、Candidでサポートされているすべての型をリストアップします。
各型について、リファレンスには以下の情報が含まれています。

  * 型の構文と、型のテキスト表現の構文。
  * 各型のアップグレード規則は、型の可能な*サブタイプ*と*スーパータイプ*の観点から示されています。
  * Rust、Motoko、およびJavascriptにおける対応する型。

サブタイプは、メソッドの*結果*を変更できる型です。
スーパータイプは、メソッドの*引数*を変更できる型です。

このリファレンスには、各型に関連する特定のサブタイプとスーパータイプのみがリストされていることに注意してください。
任意の型に適用できるサブタイプとスーパータイプに関する一般的な情報は繰り返されていません。
たとえば、`empty` は任意の型のサブタイプになり得るため、サブタイプとしてリストされていません。
同様に、`reserved` および `opt t` は任意の型のスーパータイプであるため、特定の型のスーパータイプとしてリストされていません。
`empty`, `reserved`, および `opt t` 型のサブタイピング規則の詳細については、以下のセクションを参照してください。

  * [`opt t`](https://www.google.com/search?q=%5Bhttps://www.google.com/search%3Fq%3D%2523type-opt%5D\(https://www.google.com/search%3Fq%3D%2523type-opt\))
  * [`reserved`](https://www.google.com/search?q=%5Bhttps://www.google.com/search%3Fq%3D%2523type-reserved%5D\(https://www.google.com/search%3Fq%3D%2523type-reserved\))
  * [`empty`](https://www.google.com/search?q=%5Bhttps://www.google.com/search%3Fq%3D%2523type-empty%5D\(https://www.google.com/search%3Fq%3D%2523type-empty\))

## テキスト型

`text` 型は、人間が読めるテキストに使用されます。より正確には、その値は（サロゲート部分を除く）ユニコードコードポイントのシーケンスです。

**型構文:**

`text`

**テキスト構文:**

```candid
""
"Hello"
"エスケープされた文字: \n \r \t \\ \" \'"
"Unicodeエスケープ: \u{2603} は ☃ で \u{221E} は ∞ です"
"生のバイト列 (UTF8である必要があります): \E2\98\83 も ☃ です"
```

**対応するMotoko型:**

`Text`

**対応するRust型:**

`String` または `&str`

**対応するJavaScriptの値:**

`"String"`

## blob型

`blob` 型は、バイナリデータ、つまりバイトのシーケンスに使用できます。
`blob` 型を使用して記述されたインターフェースは、`vec nat8` を使用して記述されたインターフェースと互換性があります。

**型構文:**

`blob`

**テキスト構文:**

`blob <text>`

ここで `<text>` は、すべての文字がそのUTF8エンコーディングを表すテキストリテラル、および任意のバイトシーケンス (`"\CA\FF\FE"`) を表します。

テキスト型の詳細については、[Text](https://www.google.com/search?q=%23type-text) を参照してください。

**サブタイプ:**

`vec nat8`、および `vec nat8` のすべてのサブタイプ。

**スーパータイプ:**

`vec nat8`、および `vec nat8` のすべてのスーパータイプ。

**対応するMotoko型:**

`Blob`

**対応するRust型:**

`Vec<u8>` または `&[u8]`

**対応するJavaScriptの値:**

`[ 1, 2, 3, 4, ... ]`

## nat型

`nat` 型には、すべての自然数（非負の整数）が含まれます。
これは非有界であり、任意の大きな数を表現できます。
オンワイヤエンコーディングはLEB128であるため、小さな数も効率的に表現されます。

**型構文:**

`nat`

**テキスト構文:**

```candid
1234
1_000_000
0xDEAD_BEEF
```

**スーパータイプ:**

`int`

**対応するMotoko型:**

`Nat`

**対応するRust型:**

`candid::Nat` または `u128`

**対応するJavaScriptの値:**

`BigInt(10000)` または `10000n`

## int型

`int` 型は、すべての整数を含みます。
これは非有界であり、任意に小さなまたは大きな数を表現できます。
オンワイヤエンコーディングはSLEB128であるため、小さな数も効率的に表現されます。

**型構文:**

`int`

**テキスト構文:**

```candid
1234
-1234
+1234
1_000_000
-1_000_000
+1_000_000
0xDEAD_BEEF
-0xDEAD_BEEF
+0xDEAD_BEEF
```

**サブタイプ:**

`nat`

**対応するMotoko型:**

`Int`

**対応するRust型:**

`candid::Int` または `i128`

**対応するJavaScriptの値:**

`BigInt(-10000)` または `-10000n`

## natN型とintN型

`nat8`, `nat16`, `nat32`, `nat64`, `int8`, `int16`, `int32` および `int64` 型は、そのビット数の表現を持つ数値を表し、より「低レベル」なインターフェースで使用できます。

`natN` の範囲は `{0 ... 2^N-1}` であり、`intN` の範囲は `-2^(N-1) ... 2^(N-1)-1` です。

オンワイヤ表現の長さは正確にそのビット数です。したがって、小さな値の場合、`nat` は `nat64` よりも省スペースです。

**型構文:**

`nat8`, `nat16`, `nat32`, `nat64`, `int8`, `int16`, `int32` または `int64`

**テキスト構文:**

`nat8`, `nat16`, `nat32` および `nat64` の場合は `nat` と同じです。
`int8`, `int16`, `int32` および `int64` の場合は `int` と同じです。

型注釈を使用して、異なる整数型を区別できます。

```candid
100 : nat8
-100 : int8
(42 : nat64)
```

**対応するMotoko型:**

`natN` はデフォルトで `NatN` に変換されますが、必要な場合は `WordN` に対応することもあります。
`intN` は `IntN` に変換されます。

**対応するRust型:**

対応するサイズの符号付きおよび符号なし整数。

| 長さ   | 符号付き | 符号なし |
| :----- | :------- | :------- |
| 8ビット | i8       | u8       |
| 16ビット| i16      | u16      |
| 32ビット| i32      | u32      |
| 64ビット| i64      | u64      |

**対応するJavaScriptの値:**

8ビット、16ビット、および32ビットは数値型に変換されます。
`int64` および `nat64` は、JavaScriptの `BigInt` プリミティブに変換されます。

## float32型とfloat64型

`float32` 型と `float64` 型は、単精度（32ビット）および倍精度（64ビット）のIEEE 754浮動小数点数を表します。

**型構文:**

`float32`, `float64`

**テキスト構文:**

`int` と同じ構文に加えて、次のような浮動小数点リテラルがあります。

```candid
1245.678
+1245.678
-1_000_000.000_001
34e10
34E+10
34e-10
0xDEAD.BEEF
0xDEAD.BEEFP-10
0xDEAD.BEEFp+10
```

**対応するMotoko型:**

`float64` は `Float` に対応します。
`float32` は現在、Motokoで表現できません。`float32` を使用するCandidインターフェースは、Motokoプログラムから提供することも、Motokoプログラムから使用することもできません。

**対応するRust型:**

`f32`, `f64`

**対応するJavaScriptの値:**

浮動小数点数

## bool型

`bool` 型は、`true` または `false` の値のみを持つことができる論理データ型です。

**型構文:**

`bool`

**テキスト構文:**

`true`, `false`

**対応するMotoko型:**

`Bool`

**対応するRust型:**

`bool`

**対応するJavaScriptの値:**

`true`, `false`

## null型

`null` 型は値 `null` の型であり、したがってすべての `opt t` 型のサブタイプです。また、[バリアント](https://www.google.com/search?q=%23type-variant)を使用して列挙型をモデル化する際の慣用的な選択肢でもあります。

**型構文:**

`null`

**テキスト構文:**

`null`

**スーパータイプ:**

すべての `opt t` 型。

**対応するMotoko型:**

`Null`

**対応するRust型:**

`()`

**対応するJavaScriptの値:**

`null`

## vec t型

`vec` 型は、ベクター（シーケンス、リスト、配列）を表します。
`vec t` 型の値には、型 `t` のゼロ個以上の値のシーケンスが含まれます。

**型構文:**

`vec bool`, `vec nat8`, `vec vec text` など。

**テキスト構文:**

```candid
vec {}
vec { "john@doe.com"; "john.doe@example.com" };
```

**サブタイプ:**

  * `t` が `t'` のサブタイプである場合は常に、`vec t` は `vec t'` のサブタイプです。
  * `blob` は `vec nat8` のサブタイプです。

**スーパータイプ:**

  * `t` が `t'` のスーパータイプである場合は常に、`vec t` は `vec t'` のスーパータイプです。
  * `blob` は `vec nat8` のスーパータイプです。

**対応するMotoko型:**

`[T]`。ここで、Motoko型 `T` は `t` に対応します。

**対応するRust型:**

`Vec<T>` または `&[T]`。ここで、Rust型 `T` は `t` に対応します。
`vec t` は `BTreeSet` または `HashSet` に変換できます。
`vec record { KeyType; ValueType }` は `BTreeMap` または `HashMap` に変換できます。

**対応するJavaScriptの値:**

`Array`。例：`[ "text", "text2", ... ]`

## opt t型

`opt t` 型は、型 `t` のすべての値に加えて、特別な `null` 値を含みます。
これは、ある値がオプションであることを表すために使用されます。つまり、データは型 `t` の何らかの値として存在する可能性があり、または値 `null` として存在しない可能性があります。

`opt` 型はネストできます（たとえば、`opt opt text`）。また、値 `null` と `opt null` は異なる値です。

`opt` 型は、Candidインターフェースの進化において重要な役割を果たし、以下に説明するように特別なサブタイピング規則を持ちます。

**型構文:**

`opt bool`, `opt nat8`, `opt opt text` など。

**テキスト構文:**

```candid
null
opt true
opt 8
opt null
opt opt "test"
```

**サブタイプ:**

`opt` を使用したサブタイピングの標準的な規則は次のとおりです。

  * `t` が `t'` のサブタイプである場合は常に、`opt t` は `opt t'` のサブタイプです。
  * `null` は `opt t'` のサブタイプです。
  * `t` は `opt t` のサブタイプです（ただし、`t` 自体が `null`, `opt …` または `reserved` でない場合）。

さらに、アップグレードと高階サービスに関連する技術的な理由から、*すべての*型は `opt t` のサブタイプであり、型が一致しない場合は `null` になります。ただし、ユーザーはその規則を直接使用しないことをお勧めします。

**スーパータイプ:**

  * `t` が `t'` のスーパータイプである場合は常に、`opt t` は `opt t'` のスーパータイプです。

**対応するMotoko型:**

`?T`。ここで、Motoko型 `T` は `t` に対応します。

**対応するRust型:**

`Option<T>`。ここで、Rust型 `T` は `t` に対応します。

**対応するJavaScriptの値:**

`null` は `[]` に変換されます。
`opt 8` は `[8]` に変換されます。
`opt opt "test"` は `[["test"]]` に変換されます。

## record { n : t, … } 型

`record` 型は、ラベル付きの値のコレクションです。たとえば、次のコードは、テキスト型のフィールド `street`, `city` および `country` と、数値型のフィールド `zip_code` を持つレコードの型に `address` という名前を付けています。

```candid
type address = record {
  street : text;
  city : text;
  zip_code : nat;
  country : text;
};
```

レコード型の宣言におけるフィールドの順序は重要ではありません。
各フィールドは異なる型を持つことができます（ベクターとは異なります）。
レコードフィールドのラベルには、次の例のように、32ビットの自然数を指定することもできます。

```candid
type address2 = record {
  288167939 : text;
  1103114667 : text;
  220614283 : nat;
  492419670 : text;
};
```

実際、テキストラベルはその*フィールドハッシュ*として扱われ、偶然にも `address` と `address2` は Candid にとって同じ型です。

ラベルを省略すると、Candid は自動的に連続して増加するラベルを割り当てます。この動作により、ペアやタプルを表すためによく使用される次の短縮構文が得られます。型 `record { text; text; opt bool }` は `record { 0 : text;  1: text;  2: opt bool }` と同等です。

**型構文:**

```candid
record {}
record { first_name : text; second_name : text }
record { "name with spaces" : nat; "unicode, too: ☃" : bool }
record { text; text; opt bool }
```

**テキスト構文:**

```candid
record {}
record { first_name = "John"; second_name = "Doe" }
record { "name with spaces" = 42; "unicode, too: ☃" = true }
record { "a"; "tuple"; null }
```

**サブタイプ:**

レコードのサブタイプは、追加のフィールド（任意の型）を持つレコード型、一部のフィールドの型がサブタイプに変更されたレコード型、またはオプションのフィールドが削除されたレコード型です。ただし、メソッドの結果でオプションのフィールドを削除することは悪い慣行です。フィールドがもはや使用されていないことを示すには、フィールドの型を `opt empty` に変更できます。

たとえば、次の型のレコードを返す関数がある場合：

```candid
record {
  first_name : text; middle_name : opt text; second_name : text; score : int
}
```

それを、次の型のレコードを返す関数に進化させることができます：

```candid
record {
  first_name : text; middle_name : opt empty; second_name : text; score : nat; country : text
}
```

ここでは、`middle_name` フィールドを非推奨にし、`score` の型を変更し、`country` フィールドを追加しました。

**スーパータイプ:**

レコードのスーパータイプは、一部のフィールドが削除されたレコード型、一部のフィールドの型がスーパータイプに変更されたレコード型、またはオプションのフィールドが追加されたレコード型です。

後者は、引数レコードに追加のフィールドを追加できるようにするものです。古いインターフェースを使用するクライアントは、レコードにそのフィールドを含めませんが、アップグレードされたサービスで予期される場合、`null` としてデコードされます。

たとえば、次の型のレコードを予期する関数がある場合：

```candid
record { first_name : text; second_name : text; score : nat }
```

それを、次の型のレコードを予期する関数に進化させることができます：

```candid
record { first_name : text; score: int; country : opt text }
```

**対応するMotoko型:**

レコード型がタプルを参照する可能性がある場合（つまり、0から始まる連続したラベル）、Motokoのタプル型（たとえば `(T1, T2, T3)`）が使用されます。それ以外の場合は、Motokoのレコード `({ first_name  :Text, second_name : Text })` が使用されます。
フィールド名がMotokoの予約語である場合は、アンダースコアが付加されます。したがって、`record { if : bool }` は `{ if_ : Bool  }` に対応します。
それでもフィールド名が有効なMotoko識別子でない場合は、代わりに*フィールドハッシュ*が使用されます。`record { ☃ : bool }` は `{ _11272781_ : Boolean }` に対応します。

**対応するRust型:**

`#[derive(CandidType, Deserialize)]` トレイトを持つユーザー定義の `struct`。
`#[serde(rename = "DifferentFieldName")]` 属性を使用して、フィールド名を変更できます。
レコード型がタプルの場合、`(T1, T2, T3)` などのタプル型に変換できます。

**対応するJavaScriptの値:**

レコード型がタプルの場合、値は配列に変換されます（例：`["Candid", 42]`）。
それ以外の場合は、レコードオブジェクトに変換されます（例：`{ "first name": "Candid", age: 42 }`）。
フィールド名がハッシュの場合、フィールド名として `_hash_` を使用します（例：`{ _1_: 42, "1": "test" }`）。

## variant { n : t, … } 型

`variant` 型は、与えられたケース（または*タグ*）のうちの正確に1つからの値を表します。したがって、次の型の値：

```candid
type shape = variant {
  dot : null;
  circle : float64;
  rectangle : record { width : float64; height : float64 };
  "💬" : text;
};
```

は、ドット、または円（半径付き）、または長方形（寸法付き）、または吹き出し（テキスト付き）のいずれかです。吹き出しは、ユニコードラベル名（💬）の使用を示しています。

バリアントのタグは、レコードのラベルと同様に実際には数値であり、文字列タグはそのハッシュ値を参照します。

多くの場合、一部またはすべてのタグはデータを持ちません。上記の `dot` のように、`null` 型を使用するのが慣用的な方法です。実際、Candid はバリアントで `: null` 型注釈を省略できるようにすることで、これを推奨しています。したがって：

```candid
type season = variant { spring; summer; fall; winter }
```

は次と同等であり：

```candid
type season = variant {
  spring : null; summer: null; fall: null; winter : null
}
```

列挙型を表すために使用されます。

`variant {}` 型は有効ですが、値はありません。それが意図である場合、[`empty` 型](https://www.google.com/search?q=%5Bhttps://www.google.com/search%3Fq%3D%2523type-empty%5D\(https://www.google.com/search%3Fq%3D%2523type-empty\)) の方が適切かもしれません。

**型構文:**

```candid
variant {}
variant { ok : nat; error : text }
variant { "name with spaces" : nat; "unicode, too: ☃" : bool }
variant { spring; summer; fall; winter }
```

**テキスト構文:**

```candid
variant { ok = 42 }
variant { "unicode, too: ☃" = true }
variant { fall }
```

**サブタイプ:**

バリアント型のサブタイプは、一部のタグが削除され、一部のタグ自体の型がサブタイプに変更されたバリアント型です。

メソッドの結果でバリアントに新しいタグを*追加*できるようにしたい場合は、バリアント自体が `opt …` でラップされている場合に可能です。これには事前の計画が必要です\! インターフェースを設計する際に、次のように記述する代わりに：

```candid
service {
  get_member_status (member_id : nat) -> (variant {active; expired});
}
```

次のように使用する方が良いでしょう：

```candid
service {
  get_member_status (member_id : nat) -> (opt variant {active; expired});
}
```

このようにすると、後で `honorary` メンバーシップステータスを追加する必要がある場合に、ステータスのリストを拡張できます。古いクライアントは、不明なフィールドを `null` として受け取ります。

**スーパータイプ:**

バリアント型のスーパータイプは、追加のタグを持つバリアントであり、一部のタグの型がスーパータイプに変更されている可能性があります。

**対応するMotoko型:**

バリアント型は、次のようなMotokoのバリアント型として表現されます：

```motoko
type Shape = {
  #dot : ();
  #circle : Float;
  #rectangle : { width : Float; height : Float };
  #_2669435721_ : Text;
};
```

タグの型が `null` の場合、これはMotokoでは `()` に対応し、列挙型をバリアントとしてモデル化するそれぞれの慣用的な方法間のマッピングを維持することに注意してください。

**対応するRust型:**

`#[derive(CandidType, Deserialize)]` トレイトを持つユーザー定義の `enum`。
`#[serde(rename = "DifferentFieldName")]` 属性を使用して、フィールド名を変更できます。

**対応するJavaScriptの値:**

単一のエントリを持つレコードオブジェクト。たとえば、`{ dot: null }`。
フィールド名がハッシュの場合、フィールド名として `_hash_` を使用します（例：`{ _2669435721_: "test" }`）。

## func (…) -\> (…) 型

Candid は、サービスが他のサービスやそのメソッドへの参照を（たとえばコールバックとして）受け渡す高階のユースケースをサポートするように設計されています。
`func` 型はこの中心となるものです。これは関数の*シグネチャ*（引数と結果の型、アノテーション）を示し、この型の値はそのシグネチャを持つ関数への参照です。

サポートされているアノテーションは次のとおりです。

  * `query` は、参照される関数がクエリメソッドであることを示します。つまり、そのカニスターの状態を変更せず、より安価な「クエリ呼び出し」メカニズムを使用して呼び出すことができます。
  * `oneway` は、この関数が応答を返さないことを示し、fire-and-forgetのシナリオを意図しています。

パラメータの命名の詳細については、[引数と結果の命名](https://www.google.com/search?q=candid-concepts%23service-naming)を参照してください。

**型構文:**

```candid
func () -> ()
func (text) -> (text)
func (dividend : nat, divisor : nat) -> (div : nat, mod : nat);
func () -> (int) query
func (func (int) -> ()) -> ()
```

**テキスト構文:**

現在、プリンシパルによって識別されるサービスの公開メソッドのみがサポートされています。

```candid
func "w7x7r-cok77-xa".hello
func "w7x7r-cok77-xa"."☃"
func "aaaaa-aa".create_canister
```

**サブタイプ:**

関数型への次の変更は、[サービスのアップグレード](https://www.google.com/search?q=candid-concepts%23upgrades)の規則で説明されているように、それをサブタイプに変更します。

  * 結果の型リストを拡張できます。
  * パラメータの型リストを短縮できます。
  * パラメータの型リストをオプションの引数（型 `opt …`）で拡張できます。
  * 既存のパラメータの型を*スーパータイプ*に変更できます\! 言い換えれば、関数型は引数の型に関して*反変*です。
  * 既存の結果の型をサブタイプに変更できます。

**スーパータイプ:**

関数型への次の変更は、それをスーパータイプに変更します。

  * 結果の型リストを短縮できます。
  * 結果の型リストをオプションの引数（型 `opt …`）で拡張できます。
  * パラメータの型リストを拡張できます。
  * 既存のパラメータの型を*サブタイプ*に変更できます\! 言い換えれば、関数型は引数の型に関して*反変*です。
  * 既存の結果の型をスーパータイプに変更できます。

**対応するMotoko型:**

Candid 関数型は、`shared` Motoko 関数に対応し、結果の型は `async` でラップされます（`oneway` でアノテーションされている場合を除く。その場合、結果の型は単に `()` です）。引数と結果はタプルになります。ただし、正確に1つの引数または結果がある場合は、直接使用されます。

```candid
type F0 = func () -> ();
type F1 = func (text) -> (text);
type F2 = func (text, bool) -> () oneway;
type F3 = func (text) -> () oneway;
type F4 = func () -> (text) query;
```

これはMotokoでは次のように対応します。

```motoko
type F0 = shared () -> async ();
type F1 = shared Text -> async Text;
type F2 = shared (Text, Bool) -> ();
type F3 = shared (text) -> ();
type F4 = shared query () -> async Text;
```

**対応するRust型:**

`candid::IDLValue::Func(Principal, String)`。[IDLValue](https://docs.rs/candid/0.6.15/candid/parser/value/enum.IDLValue.html) を参照してください。

**対応するJavaScriptの値:**

`[Principal.fromText("aaaaa-aa"), "create_canister"]`

## service {…} 型

サービスは、個々の関数への参照（[`func` 型](https://www.google.com/search?q=%5Bhttps://www.google.com/search%3Fq%3D%2523type-func)を使用](https://www.google.com/search?q=%23type-func)を使用)）だけでなく、サービス全体の参照も受け渡したい場合があります。この場合、Candid 型を使用して、そのようなサービスの完全なインターフェースを宣言できます。

サービス型の構文の詳細については、[Candid サービス記述](https://www.google.com/search?q=candid-concepts%23candid-service-descriptions)を参照してください。

**型構文:**

```candid
service {
  add : (nat) -> ();
  subtract : (nat) -> ();
  get : () -> (int) query;
  subscribe : (func (int) -> ()) -> ();
}
```

**テキスト構文:**

```candid
service "w7x7r-cok77-xa"
service "zwigo-aiaaa-aaaaa-qaa3a-cai"
service "aaaaa-aa"
```

**サブタイプ:**

サービス型のサブタイプは、追加のメソッドを持つ可能性があり、既存のメソッドの型がサブタイプに変更されたサービス型です。
これは、[サービスのアップグレード](https://www.google.com/search?q=candid-concepts%23upgrades)のアップグレード規則で説明されている原則とまったく同じです。

**スーパータイプ:**

サービス型のスーパータイプは、一部のメソッドが削除され、既存のメソッドの型がスーパータイプに変更されたサービス型です。

**対応するMotoko型:**

Candid のサービス型は、Motoko の `actor` 型に直接対応します。

```motoko
actor {
  add : shared Nat -> async ()
  subtract : shared Nat -> async ();
  get : shared query () -> async Int;
  subscribe : shared (shared Int -> async ()) -> async ();
}
```

**対応するRust型:**

`candid::IDLValue::Service(Principal)`。[IDLValue](https://docs.rs/candid/0.6.15/candid/parser/value/enum.IDLValue.html) を参照してください。

**対応するJavaScriptの値:**

`Principal.fromText("aaaaa-aa")`

## principal 型

インターネットコンピュータは、カニスター、ユーザー、およびその他のエンティティを識別するための共通スキームとして*プリンシパル*を使用します。

**型構文:**

`principal`

**テキスト構文:**

```candid
principal "w7x7r-cok77-xa"
principal "zwigo-aiaaa-aaaaa-qaa3a-cai"
principal "aaaaa-aa"
```

**対応するMotoko型:**

`Principal`

**対応するRust型:**

`candid::Principal` または `ic_types::Principal`

**対応するJavaScriptの値:**

`Principal.fromText("aaaaa-aa")`

## reserved 型

`reserved` 型は、1つの（無意味な）値 `reserved` を持つ型であり、他のすべての型のスーパータイプです。

`reserved` 型は、メソッドの引数を削除するために使用できます。次のシグネチャを持つメソッドを考えてみましょう。

```candid
service {
  foo : (first_name : text, middle_name : text, last_name : text) -> ()
}
```

そして、`middle_name` はもう不要になったと仮定します。Candid はシグネチャを次のように変更することを妨げませんが：

```candid
service {
  foo : (first_name : text, last_name : text) -> ()
}
```

これは壊滅的な結果になります。クライアントが古いインターフェースを使用してあなたと通信する場合、あなたは `last_name` を黙って無視し、`middle_name` を `last_name` として扱います。メソッドのパラメータ名は単なる慣例であり、メソッドの引数はその位置によって識別されることを覚えておいてください。

代わりに、次のように使用できます。

```candid
service {
  foo : (first_name : text, middle_name : reserved, last_name : text) -> ()
}
```

`foo` が以前は2番目の引数を受け取っていたが、もはやそれに関心がないことを示すためです。

引数が変更される可能性のある関数、または引数が型ではなく位置によってのみ区別できる関数は、単一のレコードを受け取るように宣言するというパターンを採用することで、この落とし穴を回避できます。
例：

```candid
service {
  foo : (record { first_name : text; middle_name : text; last_name : text}) -> ()
}
```

これで、シグネチャを次のように変更すると：

```candid
service {
  foo : (record { first_name : text; last_name : text}) -> ()
}
```

正しい動作をし、削除された引数のレコードを保持する必要さえありません。

**注記:** 一般的に、メソッドから引数を削除することはお勧めできません。通常、引数を省略する新しいメソッドを導入する方が望ましいです。

**型構文:**

`reserved`

**テキスト構文:**

`reserved`

**サブタイプ:**

すべての型

**対応するMotoko型:**

`Any`

**対応するRust型:**

`candid::Reserved`

**対応するJavaScriptの値:**

任意の値

## empty 型

`empty` 型は値を持たない型であり、他のすべての型のサブタイプです。

`empty` 型の実際的なユースケースは比較的まれです。
メソッドを「決して正常に返らない」とマークするために使用できます。
例：

```candid
service : {
  always_fails () -> (empty)
}
```

**型構文:**

`empty`

**テキスト構文:**

この型には値がないため、ありません。

**スーパータイプ:**

すべての型

**対応するMotoko型:**

`None`

**対応するRust型:**

`candid::Empty`

**対応するJavaScriptの値:**

この型には値がないため、ありません。
