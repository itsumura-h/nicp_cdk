# NimによるCandidレコード動的表現の詳細設計

## 背景と目的

ICP（Internet Computer）向けのCanister開発において、データのシリアライズ形式である**Candid**をNim言語で扱うため、動的な値表現が必要です。特にCandidの`record`型はフィールド名がハッシュ化された数値IDで管理されますが、開発者には文字列キーで直感的に操作できるようにしたいと考えています。また、Candidにはブール値や数値、文字列、配列、ネストしたレコード、オプション型、バリアント型、プリンシパル（Principal）など**多様なデータ型**が存在します。これらをNim上でJSONのように扱える**動的データ構造**とし、さらにJSONライクなテキスト表現への変換機能も提供することが目標です。

本設計ドキュメントでは、Nim標準ライブラリの`JsonNode`を参考にしつつ、Candidの全型を包括的に保持・操作できる動的構造体（仮に`CandidValue`型と呼称）の設計を行います。特に以下の点に焦点を当てます。

* **Nim標準JsonNode構造とAPI調査:** JSONデータを動的に扱う`JsonNode`の仕組みを理解し、設計の指針とする。
* **Candid型とNim構造体のマッピング:** Candidの各データ型（Bool, 数値各種, Text, Null, Record, Variant, Option, Principal, Func, Serviceなど）をNim上でどのような型・値で表現するか設計する。
* **Record型の文字列キーアクセス:** Candidレコードのフィールド名ハッシュ化と、Nim上での文字列キーによるアクセス方法を設計する（ハッシュ関数の利用とアクセサの仕様）。
* **データ構造と操作API:** 上記を踏まえ、`CandidValue`の具体的なデータ構造（オブジェクトのvariant型）と、生成・読み出し・書き込み・削除・JSON変換といった操作APIの詳細設計を行う。Nimコード例も交え、実際の利用シナリオを示す。

以下、各項目について詳細に述べます。

## Nim標準ライブラリのJsonNode構造と操作

NimにはJSONを動的に扱うための型`JsonNode`が標準提供されています。この`JsonNode`は\*\*オブジェクトvariant（可変部分を持つオブジェクト）\*\*として実装されており、内部に種類を示す`kind`フィールドを持ちます。`kind`の値によって、格納されるデータが異なる仕組みです。たとえば:

* `JNull` (null値)
* `JBool` (ブール値)
* `JInt` (整数値)
* `JFloat` (浮動小数点値)
* `JString` (文字列)
* `JArray` (配列)
* `JObject` (オブジェクト/連想配列)

`JsonNode`の種別は`jsonNode.kind`で取得でき、それに応じたプロパティにアクセスします。特に `JObject`の場合、内部に`fields`という `OrderedTable[string, JsonNode]`（キーが文字列で値がJsonNodeの順序付きハッシュマップ）を保持し、フィールド名→値のマッピングを持ちます。一方、`JArray`の場合は内部に`elems: seq[JsonNode]`（JsonNodeのシーケンス）があり、配列要素を順序通り保持します。他のプリミティブ種別では、例えば`JBool`なら内部に`bool`型の値、`JInt`なら整数値、といったフィールドを持ちます。

**JsonNodeの主な操作:**
Nimの`json`モジュールでは直感的な操作が可能なよう、演算子やヘルパーが定義されています。

* **生成:** `newJObject()`, `newJArray()`, `newJInt(n)`, `newJString(s)` などのコンストラクタが用意されています。また、リテラルから`JsonNode`を組み立てるために `%*` というマクロも提供され、簡潔にJSONリテラルを書くことができます。例えば `%* {"element": element, "atomicNumber": atomicNumber}` のように記述すると、与えたキー・値から`JObject`を生成できます。

* **フィールドアクセス:** `JObject`に対しては `node["キー名"]` というインデックス記法でサブ要素にアクセスできます。存在しないキーを`[]`でアクセスすると例外が発生します。代わりに安全なアクセスとして `node{"キー名"}` と中括弧を使うと、存在しない場合は `nil` を返す仕様です。また、`contains(node, key)` プロシージャでキーの存在確認も可能です。

* **値の取得:** 取得した`JsonNode`からNimの基本型に変換するヘルパーとして、`getInt()`, `getFloat()`, `getStr()`, `getBool()` などが用意されています。例えば `node["age"].getInt()` のようにして整数値を取り出せます。オプションでデフォルト値を指定でき、存在しない場合に既定値を返すオーバーロードも存在します。

* **値の設定:** `JObject`に対して `node["キー名"] = 新JsonNode値` という代入文でフィールドの追加・更新ができます。また、配列の場合は `node[インデックス] = 値` による要素の更新や、`add(parent, child)` プロシージャによる子要素追加もサポートされています。

* **削除:** オブジェクトからフィールドを削除する `delete(obj, key)` が用意されており、`obj.delete("キー名")`によってそのフィールドを取り除けます。

* **文字列化:** `JsonNode`は `$` 演算子（`$jsonNode`）でJSON文字列に変換できます。このとき、キーは元の順序で並び、人間に読みやすいJSONテキストとなります（Nimの実装では`OrderedTable`によってオブジェクトのキー順序が保持されます）。

上記の`JsonNode`の設計・機能は、Candid値の動的表現を考える上で大いに参考になります。次節では、Candidのデータ型をNim上でどのようにマッピングするかを検討します。

## Candidのデータ型とNimでのマッピング設計

Candidがサポートする主なデータ型と、そのNim上での表現方針を以下にまとめます。Candidの型はJSONに比べて多彩であり、**動的な型ホルダ**である`CandidValue`（仮称）にはこれら全てを格納できるようにする必要があります。

* **Null型:** Candidの`null`は値を持たないユニット型です。これは`CandidValue`内では`CVNull`（Candid Value Null）といった種別を設け、`JsonNode`の`JNull`に相当する扱いをします。内部には特に値を持ちません。

* **Bool型:** Candidの`bool`は真偽値です。Nimの`bool`で保持し、`CVBool`種別で表現します。内部に`boolVal: bool`を持つイメージです。

* **数値型:** Candidには符号付き/無しの**任意精度整数**（`Int`, `Nat`）から、固定サイズ整数（8,16,32,64ビットの`Int8/16/32/64`および`Nat8/16/32/64`）、さらに浮動小数点数（`Float32`, `Float64`）まで多様な数値型があります。動的構造では、可能な限り**統一的かつ範囲損失なく**扱えることが望ましいです。設計方針として:

  * **任意精度整数 (`Int`/`Nat`):** Nim標準ではデフォルトの整数型`int`は64ビット精度ですが、Candidの`Int`/`Nat`は理論上任意の大きさを持ちます。そのため、Nimの`bigints`モジュール等で提供される**多倍長整数**（例えば`BigInt`型）で保持することを検討します。`CandidValue`では例えば`CVInt`種別に`intVal: BigInt`を持たせ、符号付き整数値を保持します。同様に`Nat`（非負整数）も`BigInt`で保持し得ますが、符号を持たない点のみ異なります。設計上は`CVInt`ひとつで`Int`/`Nat`を区別せず保持し、符号有無は保持する値で判断するか、あるいは`CVNat`種別を別途設ける方法があります。ここでは利便性のため**符号付き/無しを区別せず**`CVInt`で包括的に保持し、必要に応じて符号チェックする設計とします（ただし型情報が必要な場面では注意が必要です）。
  * **固定サイズ整数:** `Int8`/`Int16`などの値も、範囲内であれば上記`BigInt`で保持できます。動的値としてはサイズ違いを意識せず`CVInt`に格納し、エンコード時にビット幅に合わせて出力する形にします。必要であれば種別を細分化（例えば`CVInt32`等）し、内部にNimの対応するビット幅の型（`int32`等）を保持することも可能ですが、実装複雑化とのトレードオフです。本設計ではシンプルさを優先し、整数はひとまず`CVInt`（多倍長）で一括管理します。
  * **浮動小数点数:** `Float32`と`Float64`はそれぞれ単精度・倍精度の浮動小数点です。これらはNimの`float32`および`float64`型（もしくは単に`float`型）で保持します。内部表現の精度を失わないよう、`CVFloat32`と`CVFloat64`など**別種別**で管理し、それぞれ`float32Val: float32`、`float64Val: float`のようなフィールドを持たせます。こうすることで元の型サイズを維持し、再エンコード時に正確な型で出力できます。

* **Text型:** Candidの`text`はUTF-8文字列です。これはNimの`string`で問題なく扱えます。`CandidValue`では`CVText`種別を用意し、内部に`strVal: string`を保持します。

* **Blob型:** Candidの`blob`はバイナリデータ（「`vec nat8`」型のシノニム）です。JSONには相当する型がありませんが、本設計では特別に区別します。`CVBlob`種別を設け、内部にNimの`seq[uint8]`（バイト列）や`array[byte]`等でデータを保持します。プリンシパルIDなどは内部でバイナリ表現を持つため、`blob`として扱うケースもあります。JSONライクな文字列化では、`blob`は例えばBase64エンコードした文字列や、あるいは各バイトの数値配列として出力することが考えられます（詳細は後述）。

* **Record型:** Candidの`record`はいわゆる構造体・連想配列で、**フィールド名がハッシュ化された整数ID**にマッピングされて保持されます。ただし開発者にとっては文字列のフィールド名で扱う方が直感的です。Nimの`JsonNode`における`JObject`と同様、`CandidValue`では`CVRecord`種別を用意し、内部にフィールド名から子`CandidValue`へのマップを保持します。キーは**文字列**で持ち、値はネストした`CandidValue`です。Nim標準の`Table`あるいは順序保持のため`OrderedTable[string, CandidValue]`を利用します。**内部ではキー名をそのまま保持**しますが、エンコード（シリアライズ）時にはこのキー文字列を所定のハッシュ関数で32ビット整数IDに変換して用います（詳細は次節）。なお、一つのレコード内でフィールド名のハッシュ値が衝突することはCandid仕様上許可されません。もし仮に異なる名前から同一のハッシュIDが計算される場合、そのレコード型定義自体が不正となります。この性質により、キー文字列→IDのマッピングは一意に定まります。

* **Variant型:** Candidの`variant`は列挙型に似た**タグ付き合併型**です。複数のタグ（ケース）から一つを選び、そのケースに対応する値（あるいは値を持たないケースも可）を取ります。`variant`のタグ名も内部的にはハッシュ化されたIDとして管理されます。`CandidValue`では`CVVariant`種別を用意し、内部に選択されたタグ名と、そのタグに対応する値の`CandidValue`を保持します。具体的には例えば `variantTag: string` と `variantVal: CandidValue` を持つ形です。値を持たないケースの場合、`variantVal`は`CVNull`相当の値（または内部的に`nil`）で表現できます。Variantのタグ名→ID変換もRecord同様に32ビットハッシュ関数で行い、エンコード時に使用します。デコード時に型情報なしで値を読み込むと、variantタグも数値でしか取得できませんが、本設計では**基本的に型情報とセットで動的値を生成する**ことを想定し、タグ名も保持できるようにします。

* **Option型:** Candidの`opt T`（オプション型）は`T`型の値を持つか、または値なし（`null`とは別概念のNone）かを表します。実質的には`variant { none; some: T }`に近い構造です。`CandidValue`では`CVOption`種別を用意し、内部に`hasValue: bool`（値があるか）と`optVal: CandidValue`（値がある場合の中身）を保持する設計とします。例えば値が存在しない（None）の場合は`hasValue = false`で`optVal`は未使用（または`nil`）とし、値がある（Some）場合は`hasValue = true`で`optVal`にその値を格納します。**注意:** Candidの`null`型の値と、`opt T`のNoneは区別されます。OptionがNoneの場合でも`optVal`は型`T`が何かを表現できるよう保持するのが望ましいですが、本動的構造では型情報を持たないため、`None`の場合に型は失われます。エンコード時には文脈（予想される型情報）から対処する必要がありますが、詳細は後述します。

* **Principal型:** Candidの`principal`はCanisterやユーザを識別するエンティティIDです。内部的には最大29バイト程度のバイナリデータで、テキスト表現ではBase32の文字列（例: `aaaaa-aa` 形式）となります。`CandidValue`では`CVPrincipal`種別を用意し、Nim上でプリンシパルを扱う型（例えば`PrincipalId`構造体や単に`string`表現）で保持します。ここでは簡易化のため**テキスト表現の文字列**で保持するとします（内部バイナリが必要な場合は適宜変換）。エンコード時にはこの文字列を検証しバイナリ形式へ変換します。

* **Func型:** Candidの`func`はファンクション参照で、ペア `(principal, method_name)` で表されます。principalはターゲットCanister、method\_nameはその関数名です。これも`CandidValue`で`CVFunc`種別とし、内部に `(principal: PrincipalId, method: string)` のタプルや構造体を保持します。例えば`funcVal: tuple[principal: PrincipalId, method: string]`のようにします。Principalの扱いは上記`CVPrincipal`と同様ですが、method名は通常の文字列です。

* **Service型:** `service`はサービス（Canister）参照で、principalとインターフェース型IDを持つ場合があります。ここでは主にprincipalがあれば十分とみなし、`CVService`種別を設けて`serviceId: PrincipalId`のみ保持します（必要に応じて型記述を別途管理）。事実上`CVPrincipal`に近い扱いです。

* **Reserved / Empty型:** Candidには特殊型として`reserved`と`empty`があります。`reserved`はどんな値にもマッチするトップ型、`empty`はどんな値も取り得ないボトム型です。これらは通常データ保持には現れませんが、`reserved`はデコード時に「値を捨てる」用途で使われることがあります。動的値の設計上は、特に専用の種別を設けず\*\*`reserved`は任意の値を格納できる型として特別扱い不要\*\*、`empty`は値を持つことがないため動的値自体としては出現しない、と整理します。ただし、型情報として`reserved`を指定された場合は値を保持しても無視するといった処理が別途必要です（本ドキュメントの範囲では型定義の扱いは深入りしません）。

以上のマッピングにより、Candidで表現可能な全ての値をNim上の`CandidValue`で保持できます。次に、Record型のフィールド名ハッシュ化と、それを透過的に扱う仕組みについて詳述します。

## Recordフィールド名のハッシュ化と文字列キーアクセサ

**CandidのRecord構造:** 前述の通り、Candidのレコードはフィールド名ではなく**フィールドID**（32ビット整数）によってフィールドを識別します。フィールドIDは通常、フィールド名文字列から計算されるハッシュ値として定義されます。Candid仕様では、異なる名前のフィールドが同一のID（ハッシュ値）になることはそのレコード内では許されず、もし衝突すれば型定義エラーとなります。このハッシュ関数には**32ビット長の結果**を出力するものが用いられており、フィールド名から決まる一意のIDとして機能します。

ハッシュ関数の正確な仕様はCandidのインターフェース仕様で定義されていますが、例えば「フィールド名が数字のみで構成されている場合はその数値をIDとみなし、そうでない場合はSHA-224ベースのハッシュを32ビットにトリミングする」などのルールがあります（参考: Candidの実装やDFINITYフォーラムの議論）。重要な点は**同じ名前からは常に同じIDが得られる**ことと、**IDから元の名前を一意に逆引きすることはできない**ことです。実際、Candidバイナリにはフィールド名が含まれずIDのみ格納されるため、デコード時に型情報が無いとフィールド名が再現できず、数値のまま出力されます。例えば、`record { first_name = "John"; age = 24 }` を型情報なしにデコードすると `(record { 2797692922 = "John"; 4846783 = 24 })` のように数値キーになることが知られています。

**文字列キーでのアクセス:** 我々のNim実装では、開発者にはレコードを**文字列のフィールド名**で扱わせ、内部で必要に応じハッシュ変換を行います。具体的な仕組みは以下の通りです。

* `CandidValue`の`CVRecord`は内部に `fields: OrderedTable[string, CandidValue]` を保持し、キーとして**そのまま人間可読のフィールド名文字列**を使います。例えばフィールド名`"name"`であればキーも`"name"`文字列です。開発者がレコードにアクセスするときも、このキー文字列を使います。

* **フィールド追加/更新:** 開発者が `rec["fieldName"] = value` と代入した際、実装側では即座に `"fieldName"` をハッシュ計算し32ビットIDを求めます。そして`fields`マップにキー`"fieldName"`で`value`を保存します。同時に、計算したハッシュIDはレコードのメタデータとして保持しておくとエンコード時に再計算せずに済み効率的です。例えば内部的に `fieldIdMap: Table[string, uint32]` を持ち、追加時に `fieldIdMap["fieldName"] = 0xABCD1234` のように記録しておきます。簡略化のために設計上は再計算でも問題ありませんが、実装上のキャッシュとして念頭に置いておきます。

* **フィールド取得:** `rec["fieldName"]` でアクセスされた場合、実装は単純に`fields`テーブルからキー`"fieldName"`を検索し、対応する`CandidValue`を返します。開発者はハッシュIDを意識する必要はありません。Nimの`JsonNode`同様、そのキーが存在しない場合は`KeyError`例外を発生させます。存在有無が不確かな場合、`rec.contains("fieldName")`で確認したり、`rec.get("fieldName")`（または`rec{"fieldName"}`）のような安全アクセスで`nil`（存在しなければ）または値を取得できるインターフェースも提供します。

* **ハッシュID直接指定:** 開発者がフィールド名ではなく、ハッシュ済みIDを直接指定するケースは通常ありません。しかし何らかの高度な用途でIDを指定したい場合に備え、例えばキー文字列を`"_{ID}_"`という特殊な形式で渡された場合には、そのID値を直接用いる、といった約束も考えられます。例えば `rec["_42_"]` と書けばID=42のフィールドにアクセスする、といった具合です。この機能は通常不要ですが、JSONテキスト出力時などで数値キーを区別するために、`_..._`で囲まれたキーは「数値ID」とみなす仕様を採用します。

* **フィールド削除:** `rec.delete("fieldName")`または`delete(rec, "fieldName")`で、マップからキー`"fieldName"`を削除します。併せて内部で保持していたハッシュIDの記録も削除します。

**エンコード時の処理:** `CandidValue`構造からCandidバイナリメッセージを生成（エンコード）する際、レコードについては以下の手順を踏みます。

1. `fields`マップから各キー文字列を取り出し、ハッシュ関数で32ビットIDを計算します（必要ならキャッシュ値を使用）。
2. IDの**昇順**にフィールドを並べ替えます。CandidのレコードはフィールドIDの昇順でシリアライズする規約があるためです。
3. 並び替えた順に各フィールドの値をエンコードしていきます（型情報テーブルでは同じID順で記述されます）。

このように、格納時・アクセス時は文字列ベース、エンコード時のみハッシュIDを意識する設計となっています。デコード（バイナリ→構造）時には型情報がある場合は逆にID→名前へのマッピングを行います。通常これはあらかじめ型に紐づく名前情報から行いますが、もし型情報なしでデコードした場合、一時的にキーを`"_{ID}_"`形式の文字列や単純に数値文字列として格納し、後から適切な名前が判明した段階で差し替えるといった方針も考えられます。

以上の仕組みにより、開発者は**文字列のフィールド名で自然にレコードを操作**でき、内部的なハッシュIDの存在を意識する必要がありません。

## CandidValueデータ構造と操作APIの設計

上述のマッピングと要件を踏まえ、Nimで実装する`CandidValue`型の具体像と、それに付随するAPI（生成・操作・変換）を設計します。基本方針はNimの`JsonNode`と似ていますが、Candid特有の型にも対応する点が異なります。以下では擬似コードを交えて説明します。

### データ構造の定義 (オブジェクトvariant)

まず`CandidValue`自体を**オブジェクトvariant**として定義します。Nimでは`case`節を用いてvariantオブジェクトを定義できます。その`kind`フィールドにより有効なフィールドが切り替わる形です。概略の定義は次のようになります。

```nim
type
  CandidKind* = enum
    ckNull, ckBool, ckInt, ckFloat32, ckFloat64, ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService

  CandidValue* = ref object
    case kind*: CandidKind
    of ckNull:
      discard  # 値を持たない
    of ckBool:
      boolVal*: bool
    of ckInt:
      intVal*: BigInt           # arbitrary precision integer
      # (Nat も符号付きとして格納; 必要なら符号チェック)
    of ckFloat32:
      f32Val*: float32
    of ckFloat64:
      f64Val*: float            # Nimのfloatはデフォルトで64bit
    of ckText:
      strVal*: string
    of ckBlob:
      bytesVal*: seq[uint8]
    of ckRecord:
      fields*: OrderedTable[string, CandidValue]
    of ckVariant:
      variantTag*: string
      variantVal*: CandidValue   # 値を持たない場合 null 相当可
    of ckOption:
      hasValue*: bool
      optVal*: CandidValue      # hasValue=falseのとき未使用 (nil可)
    of ckPrincipal:
      principalId*: string      # principalのテキスト表現 (例: "aaaaa-aa")
    of ckFunc:
      funcRef*: tuple[principal: string, method: string]
    of ckService:
      serviceId*: string        # principalと同じ形式で保持
```

上記に含まれない型について:

* `reserved`はどの型の値も取り得るため特別扱いしません。`reserved`型のフィールドを解釈する際は、実際にはどんな`CandidValue`も格納可能とみなします。
* `empty`は値が存在しない型なので、`CandidValue`には現れません。

このデータ構造により、単一の`CandidValue`であらゆるCandidの値を表現できます。`CandidKind`は内部的に13種類（上記enumのメンバー）を持ち、これがJSONのJNull等に相当します。以下、各種別について補足します。

* `ckNull`: 値を持たないため`discard`で定義しています。他言語でのnullと同様に扱います。
* `ckBool`: Nimの`bool`そのままです。
* `ckInt`: 任意精度整数。`BigInt`は仮にNimの多倍長整数型（例えば`mpdecimal`や`bigints`モジュールの型）とします。ない場合は符号付き64ビット`int`で代用しますが、オーバーフローの懸念があります。
* `ckFloat32`/`ckFloat64`: それぞれ単精度・倍精度の浮動小数。格納時に混同しないよう別々のvariantにしています。
* `ckText`: UTF-8文字列。Nimの`string`はUTF-8を保持できます。
* `ckBlob`: バイナリ。可変長のバイト列`seq[uint8]`で持ちます。エンコード時はそのまま出力し、デコード時は`vec nat8`は自動的に`ckBlob`になります。なお、文字列ではない点に注意します。
* `ckRecord`: フィールドマップ。OrderedTableを使うことで**フィールドの追加順序**を保存します。JSONでは順序保持は必須ではありませんが、NimのJsonNode実装では順序を保持しており、我々もこれを踏襲しました。これはエンコード結果の安定性やデバッグ時の見やすさに寄与します。なお、エンコード（バイナリ化）時には順序ではなくID昇順に並べ替えますが、内部順序は必ずしも昇順ではありません。
* `ckVariant`: 現在選択されているタグ名と、その値を保持します。値が無い場合は`variantVal`を`ckNull`にするか、`variantVal`自体を`nil`にする運用も可能です（後者の場合、variantValフィールドを`ref CandidValue`にする必要がありますが、簡略化のためここではvariantValは常に非nilの`CandidValue`とし、値が無ければ`ckNull`値を入れる設計とします）。
* `ckOption`: `hasValue`がfalseの場合はNone、trueの場合はSomeで`optVal`に実値を保持します。上記定義では`optVal`が`nil`可能とは記載していませんが、Nimのvariantでは`optVal`は`CandidValue`（ref型）なのでデフォルト`nil`が入り得ます。Noneの場合は`optVal == nil`でもよいし、`hasValue`で判断してもよいです。ここでは明示的に`hasValue`をチェックする設計としました。
* `ckPrincipal`/`ckService`: どちらもPrincipal IDを`string`で保持しています。`ckService`の場合、将来的にインターフェース記述子（型）も保持したければ`serviceType: someTypeDescriptor`など追加しますが、本稿では割愛します。
* `ckFunc`: principalとメソッド名の組。principalは`ckPrincipal`同様に文字列ID、メソッド名は通常の関数名文字列です。

### インスタンス生成と変換API

`CandidValue`の値を作るためのAPIとして、**コンストラクタ関数**や**ユーティリティマクロ**を提供します。Nim標準JSONが `newJObject()`, `%*`マクロなどを持つように、以下のような関数を想定します。

* `newCNull(): CandidValue` – Null値を表す`CandidValue`を返す。
* `newCBool(b: bool): CandidValue` – ブール値から生成。
* `newCInt(i: int|BigInt): CandidValue` – 整数から生成。型に応じ適切に保持（Nimのオーバーロード機能で`int`版と`BigInt`版を用意）。
* `newCFloat32(x: float32): CandidValue` / `newCFloat64(x: float): CandidValue` – 浮動小数点から生成。
* `newCText(s: string): CandidValue` – テキストから生成。
* `newCBlob(bytes: seq[uint8]): CandidValue` – バイト列から生成。
* `newCRecord(): CandidValue` – 空のレコードを生成。
* `newCVariant(tag: string, val: CandidValue): CandidValue` – 指定タグ・値のVariantを生成。
* `newCVariant(tag: string): CandidValue` – 値を持たないVariantケースを生成（内部的には`ckNull`値をセット）。
* `newCOption(val: CandidValue): CandidValue` – Some値を持つOptionを生成（hasValue=true）。
* `newCOptionNone(T: type): CandidValue` – 型`T`のNoneを生成（hasValue=false, optVal未設定）。`T`はオプション内の型情報ヒントとして使う（エンコード時などに利用）。
* `newCPrincipal(text: string): CandidValue` – Principal ID文字列から生成。
* `newCFunc(principal: string, method: string): CandidValue` – Func参照を生成。
* `newCService(principal: string): CandidValue` – Service参照を生成。

これら関数で基本的な値は生成可能です。また、Nimの構文拡張として、JSONの`%*`マクロに倣ったリテラル構築マクロも検討します。例えば `%C` というマクロを定義し、`%C { "name": "Alice", "age": 30 }` のように書けば自動的に`CandidValue`のRecordを作る、といったものです。Nimの`%*`はオブジェクトや配列リテラルを`JsonNode`にするマクロでした。同様にCandid版を実装すれば、より簡潔にリテラルから構造を構築できます。

**例: CandidValueの生成**（コード例）:

```nim
# 単純なレコード値を構築する例
var person = newCRecord()
person["name"] = newCText("Alice")
person["age"]  = newCInt(30)
person["isMember"] = newCBool(true)

# ネストしたフィールド（サブレコード）と配列
person["address"] = newCRecord()
person["address"]["city"] = newCText("Tokyo")
person["address"]["zip"]  = newCText("100-0001")

person["scores"] = newCArray()              # newCArrayは newCRecordと同様に空の配列を返す関数
let scores = person["scores"]
scores.add(newCInt(90))
scores.add(newCInt(85))
scores.add(newCInt(88))

# Variant型フィールド
person["status"] = newCVariant("Active")    # 値を持たないvariantケース（タグ"Active"）
# Option型フィールド
person["nickname"] = newCOptionNone(string) # string型のNone（値無し）
person["rating"]   = newCOption(newCInt(5)) # Some(5) 
```

上記のように、レコードはまず`newCRecord()`で生成し、その後インデックス代入でフィールドを追加しています。文字列キーで`person["name"]`のようにアクセスでき、内部でhash計算＋マップ登録が行われます。配列については`newCArray`（設計で言及漏れていましたが`ckArray`相当が必要です）を使い、`scores.add(...)`のようなメソッドで順次要素を追加しています。実装としては、`ckRecord`同様に`ckArray`種別を設け、内部に `elems: seq[CandidValue]` を持たせます（上記variant定義に`ckArray`を含め忘れたため補足します）。この`elems`に対しては

* `add(elem: CandidValue)` – 末尾に追加
* `delete(index: int)` – 指定インデックスの要素削除
* `len(array)` – 長さ取得
* インデックス演算子 `array[i]` – i番目の要素参照/設定（範囲チェック付き）

などのAPIを提供します。Nimでは既定で`proc [](a: CandidValue, i: int): var CandidValue`のように定義すれば配列アクセス演算子`[]`をオーバーロードできます。

### フィールド・要素のアクセスAPI

`CandidValue`に対してJSON同様のアクセス性を確保するため、以下のようなプロシージャや演算子を用意します。

* **レコードのキーアクセス:**

  * `proc [](cv: CandidValue; key: string): var CandidValue` – レコード（ckRecord）の場合、指定キーの値への参照を返します。存在しない場合は`KeyError`を発生させます。
  * `proc []=(cv: CandidValue; key: string; value: CandidValue)` – レコードに対するフィールド設定を行います。上記例のように`cv["foo"] = bar`で使用可能です。内部では新規キーなら追加、既存キーなら値を更新します。なお、`cv`が`ckRecord`でない場合はエラーになります（タイプミス検出目的）。
  * `proc contains(cv: CandidValue; key: string): bool` – レコード内にキーが存在するか確認します。存在する場合true。
  * `proc get(cv: CandidValue; key: string): CandidValue` – 安全な取得を行います。存在しなければ`ckNull`あるいは`nil`を返し、存在すればその値を返します。もしくはNimの`Option`型で返す設計も考えられますが、ここでは単純化します。Nim標準では`node{"key"}`というシンタックスを提供していましたが、自作型でも演算子オーバーロードで実現可能です（`template `{}`(...)`の定義などが必要）。

* **配列のインデックスアクセス:**

  * `proc [](cv: CandidValue; index: int): var CandidValue` – 配列（ckArray）の場合、指定インデックスの要素への参照を返します。範囲外の場合は`IndexError`等を出します。
  * `proc []=(cv: CandidValue; index: int; value: CandidValue)` – 配列要素の上書き。既存インデックスに対してのみ有効で、範囲外ならエラーもしくは自動拡張（今回はエラーとします）。
  * `proc add(cv: CandidValue; value: CandidValue)` – 配列の末尾に要素を追加します。実装的には`cv.elems.add(value)`するだけです。
  * `proc len(cv: CandidValue): int` – 配列長を返します（ckArray以外では0を返すようにしても良いでしょう）。

* **オプション値のアクセス:**
  Optionは特別扱いせず、開発者は`cv.kind`を見て`ckOption`なら`cv.hasValue`で判定し、`cv.optVal`を使うという手動手順でもよいですが、ヘルパーを用意して簡便化も可能です。例えば:

  * `proc isSome(cv: CandidValue): bool` – Optionかつ値ありならtrue、そうでなければfalse。
  * `proc getOpt(cv: CandidValue): CandidValue` – Optionの中身の値を取得。値なしの場合はデフォルトの`CandidValue`(例えば`ckNull`)を返すか、エラーにするか検討。Nimの`Option[T]`の`get()`は値が無ければ`UnpackDefect`を投げる仕様です。それに倣うなら、Noneの場合はエラーでもよいでしょう。

* **Variant値のアクセス:**
  Variantも専用ヘルパーを検討します。

  * `proc variantTag(cv: CandidValue): string` – Variantのタグ名を返す。
  * `proc variantVal(cv: CandidValue): CandidValue` – Variantの保持する値を返す（値を持たないケースでは`ckNull`など）。
    加えて、特定のタグか確認するヘルパー（例えば`isCase(cv, tagName: string): bool`）などを用意すると、用途によっては便利でしょう。

* **Principal, Func, Serviceのアクセス:**
  Principalは内部で単に文字列なので`cv.principalId`を直接使えば取得できます。ただし、Principalのバイナリ形式や比較用にオブジェクト化されているなら、そのメソッドを通す必要があります。ここでは詳細は省きますが、例えば`cv.asPrincipal(): PrincipalId`のような変換を提供しても良いでしょう。FuncとServiceも同様です。

* **削除:**

  * `proc delete(cv: CandidValue; key: string)` – レコードからキー`key`を削除します。実装は`if cv.kind == ckRecord: cv.fields.del(key)`のような処理になります。配列に対する`delete(cv, index: int)`も用意し、`cv.elems.remove(index)`で対応します。

**例: フィールドアクセスと操作**（コード例）:

```nim
# 上で構築した person レコードを操作する例
if person.contains("age"):
  echo person["age"].getInt()           # 30 を取得して表示
person["age"] = newCInt(31)             # ageを更新
discard person.get("nonexistentField")  # 安全取得: 該当なしならnilやckNullを返す

# 配列要素へのアクセス
let firstScoreVal = person["scores"][0].getInt()
echo firstScoreVal                      # 90 を表示
person["scores"][1] = newCInt(95)       # 2番目のスコアを85から95に変更
person["scores"].add(newCInt(100))      # スコア配列の末尾に100を追加
echo person["scores"].len()            # 長さを取得して表示（4になる）
person["scores"].delete(2)             # 3番目の要素(88)を削除

# オプションとVariantの利用
if not person["nickname"].isSome():
  person["nickname"] = newCOption(newCText("Ali"))  # ニックネームを後から設定
let ratingVal = person["rating"].getOpt()           # Some(5)が入っているので5取得
echo ratingVal.getInt()                            # 5を表示

# Variantケースの確認
person["status"] = newCVariant("Inactive")         # statusを他のケースに変更
if person["status"].variantTag() == "Inactive":
  echo "Status is now Inactive"
```

このように、直感的なインデックスやメソッドで値の操作・参照が可能です。`getInt()`や`getStr()`等のヘルパーは、それぞれ内部で型チェックと変換を行い、例えば`ckInt`ならNimの`int`に変換、`ckText`なら`string`を返す、といった処理をします。実装上、`BigInt`を`int`に変換する際に範囲オーバーする可能性がありますが、その場合は例外を投げるか上位ビットを切り捨てる仕様とします（安全側を取るなら例外）。

### JSONライクなテキストへの変換

動的構造を**JSON風の文字列**に変換する機能も提供します。これはデバッグやログ出力、あるいは開発者が内容を直感的に理解する助けとなります。Candid値はJSONにない型を持つため、完全なJSON互換ではなく**JSONに類似した表記**とするのがポイントです。

Nimの`JsonNode`では `$jsonNode` や `echo jsonNode` でJSON文字列が得られました。同様に、`CandidValue`にも `$` 演算子をオーバーロードして、人間が読める文字列を生成します。以下、各種別の変換方針を示します。

* **基本型 (Null, Bool, Int, Float, Text):** これはJSONと同様に表記できます。Nullは`null`、Boolは`true`/`false`、IntやFloatは数値（必要に応じ指数表記）で、Textはダブルクォートで囲んだ文字列として出力します。例えば`ckText("Hello")`は`"Hello"`、`ckInt(42)`は`42`となります。極大な整数はそのまま数値リテラル（BigIntでも精度は崩れませんが、JavaScriptなどで扱えない桁数になる場合があります）。Floatは`3.14`など。特に区別不要です。

* **Blob (バイナリデータ):** バイナリはそのままではJSONの数値配列にするか、文字列エンコードする必要があります。Candidのテキスト形式では`blob "..."`という表現がありますが、ここではJSONライクさを優先し、**Base64エンコードした文字列**に例えば`"base64:..."`というプレフィックスを付けて出力する方法や、単に配列 `[byte1, byte2, ...]` として出力する方法が考えられます。配列表示は可読性が低いので、Base64文字列案を採用するとします。例えばバイト列`[0x41, 0x42]`（"AB"）なら`"base64:QUI="`のように出力します。プレフィックス`base64:`が付けば人間にもバイナリと分かります。

* **Record:** JSONのオブジェクトに相当しますので、`{ "field1": ..., "field2": ... }`のように**キーと値のペア**を並べます。キー名は元の文字列を用いますが、必要に応じてエスケープや引用符を付けます。JSONではキーも必ずダブルクォートで囲む必要があります。例えば `ckRecord`でフィールド`name: "Alice", age: 30`を持つ場合、出力は `{"name": "Alice", "age": 30}` となります。

  特殊なケースとして、フィールド名が他の型と衝突する場合の処理があります。例えば数値のような名前や予約語の場合です。Candidではフィールド名が数字のみの場合、それは数値IDとみなされ得ます。当実装では文字列キーは基本そのまま出しますが、「**文字列が数字のみ**」の場合は**アンダースコアで挟んだ表記**に変換します。例えばキー `"42"`（文字列）であれば `"_42_"` として出力します。こうすることで、それが数値IDを意味することを明示できます。また、実際に内部で`_42_`というキーが使われていた場合（デコード時にIDしか無く名前不明のケース）、そのまま`"_42_"`が出力に現れます。通常の文字列キーはそのまま引用符付きで出力します。

* **Variant:** VariantはJSONに直接の表現が無いですが、**単一キーのオブジェクト**として表現するのが分かりやすいです。つまり、選択中のタグ名をキー、その中身の値を値として持つオブジェクトです。このアプローチは他の言語バインディングでも採用されており、例えばCandidをJavaScriptでやり取りする場合、Variantは `{ "TagName": <value> }` のようなオブジェクトになります（エンコード時は開発者がこういう形で提供する）。従って`ckVariant("Active", ckNull)`は `{"Active": null}`、`ckVariant("Error", ckText("msg"))`は `{"Error": "msg"}` といった出力にします。タグ名自体が衝突するリスク（たまたまRecordのフィールド名と同じ等）はありますが、JSON出力はあくまでデータの内容表示用と割り切り、深く区別はしません。Variant内部の値は再帰的にJSON変換します。

* **Option:** OptionはVariantの`some/none`に相当するため、これも**Variantと同様に**単一キーのオブジェクトで表現できます。具体的には、値がある場合 `{ "some": <value> }`、値が無い場合 `{ "none": null }` とします。例えば`ckOption(hasValue=false)`は`{"none": null}`、`ckOption(hasValue=true, optVal=ckInt(5))`は`{"some": 5}`となります。`none`の場合本来中身の型情報がありませんが、表示上は単にnullとしています（区別点としてキーが`"none"`であることが重要です）。

* **Principal:** Principalはテキスト表現（`aaaaa-bbb...`のような形式）で保持しているので、そのまま**ダブルクォート付き文字列**で出力します。例えばPrincipal ID `w7x7r-cok77-xa`であれば `"w7x7r-cok77-xa"` と出します。特別なマーカー等は付けませんが、例えば必要なら `"principal: <ID>"` のように`principal:`を付ける案もあります。しかしシンプルさを優先し、単に文字列とします。

* **Func:** 関数参照は `{ "principal": "<プリンシパルID>", "method": "<メソッド名>" }` のようなオブジェクトに変換します。キー名は固定で`principal`と`method`を使用します。例えば`ckFunc(principalId="abcd-...", method="foo")`は `{"principal": "abcd-...", "method": "foo"}` となります。場合によっては `"func": { ... }` と一段ラップすることも考えられますが、ここでは平易さを優先します。

* **Service:** サービス参照はPrincipal IDだけなので、出力は単にプリンシパル文字列、あるいは`{"service": "<ID>"}`のようにラップする方法があります。Funcと対称性を持たせるなら`{"principal": "<ID>"}`だけでも良いですが、それではFuncとの見分けがつきにくいです。ここではサービスは特殊ケースが少ないことから、シンプルにPrincipal同様の文字列だけ出力する方針とします。

**JSONライク出力の例:**
上で構築・操作した`person`レコードを`$person`で文字列化すると、以下のようになることが期待されます。

```javascript
{
  "name": "Alice",
  "age": 31,
  "isMember": true,
  "address": { "city": "Tokyo", "zip": "100-0001" },
  "scores": [ 90, 95, 100 ],
  "status": { "Inactive": null },
  "nickname": { "some": "Ali" },
  "rating": { "some": 5 }
}
```

各要素がJSON風に表現されています。`status`はVariantでタグ`Inactive`なので`{ "Inactive": null }`、`nickname`と`rating`はOptionでSome値を持つので`{ "some": "Ali" }`, `{ "some": 5 }`となっています。なお、`nickname`や`rating`がNoneだった場合は`{ "none": null }`と表示されたでしょう。

**注意:** この文字列化はデバッグ用途であり、厳密な逆変換（パース）を保証しません。特にVariantやOptionは独自表現で、JSON標準にはない構造です。また、フィールド名に`_`を含むケースや、`_123_`のようなキーは解釈上特別な意味がある（数値ID表現）ことに留意が必要です。ただし通常のデータでは問題になりません。

### Candidメッセージへの変換 (エンコード) を考慮した設計

最後に、本構造からCandidバイナリ（IDLメッセージ形式）への変換について触れておきます。`CandidValue`は動的に値を保持できますが、Candidのメッセージとして送受信するには**明確な型情報**と対応付けてエンコードする必要があります。

* **型情報の保持/推論:** 静的には型が決まっている場合（例えばRustやMotokoから受け渡されたデータをNimでデコードする際、.didファイルで型が既知）は、その型情報を使ってデコード時に適切な名前を付けたり、エンコード時に期待型に沿ったバイナリに変換できます。一方、`CandidValue`自体は値に特化した構造であり型情報を完全には保持しません。例えば空の`ckOption(None)`や空の`ckArray`では、中身の型が不明です。このため、**必要に応じて型情報を別途渡せるインターフェース**を用意します。例えば `encodeCandid(cv: CandidValue, typeDesc: CandidType)` のように、型記述子（Candidの型構造を表すオブジェクト）を引数に取る関数を設計します。型記述子にはレコードのフィールドID→型、オプションの内包型、ベクターの要素型、バリアントの各タグ型などが含まれます。これを参照しながら、`cv`内の値を正しくエンコードする形です。

  もし型情報が無い場合でも、`CandidValue`から**推論**は可能な限り行います。例えば、オプションがSomeであれば中身から型を推測できますし、配列に要素があればその型から推測します。Variantも選択中の値からそのケースの型は分かります。ただし、空配列・Noneオプション・値無しVariantなどは推論不能なので、開発者に型を渡してもらう必要があります。

* **エンコード処理:** 型情報が得られれば、あとは`CandidValue`を再帰的に辿りバイナリを構築するだけです。各種別ごとに:

  * プリミティブ（Null, Bool, 数値, Text）は対応するLEB128整数や浮動小数ビット列、文字列バイト列を出力。
  * Blobは長さとバイト列を出力。
  * Recordは前述の通りフィールドIDを算出し、ID順に子要素をエンコード。型テーブル（type description）にもID順で子タイプを並べます。
  * Variantはタグ名をハッシュ化し、対応するタグIDと、その値をエンコード。タグIDが型テーブル上で何番目か（variantはタグIDもソートされるでしょう）算出し、1バイトまたはLEB128でタグのindexを出力、続けて値本体をエンコード。
  * Optionは`some`であれば1バイトの`0x01`（タグ的な値）+ 値エンコード、`none`であれば`0x00`のみ、という形式で出力します（実際Candidのoptはvariantの特例として0/1で表現しています）。
  * PrincipalはtextをBase32デコードしてバイト列化し、先頭に長さ（1バイト）とデータを出力します。
  * Funcはprincipalと文字列をそれぞれエンコードします（形式はprincipalと同様+文字列）。
  * Serviceはprincipalをエンコードします。

このエンコード処理自体は本ドキュメントの範囲を超えますが、`CandidValue`の設計段階で**型情報と値を紐付けやすくしている**ことが重要です。例えばRecordでは**キー文字列から即座にハッシュIDを計算できる**ようにしており、Variantでもタグ名を保持しているので同様です。これはエンコード実装を簡潔にします。また、Optionで`hasValue`と`optVal`に分けたのも、None/Someの判定を容易にしシリアライズ仕様に対応しやすくするためです。

最後に、デコード（受信時）についても一言述べます。エンコードの逆ですが、バイナリにはフィールド名が無いため型情報を使ってフィールド名を割り当てる必要があります。`CandidValue`を生成する際に型情報があれば、Recordでは正しい名前で`fields`に格納し、Variantでは`variantTag`に名前を入れることができます。型情報がない場合、Recordのキーは`"_<id>_"`形式の文字列にし、Variantタグも`_<id>_`のようにしておく実装になるでしょう。その状態でJSON文字列化すれば`{"_42_": ...}`のように出力され、ハッシュIDであることがわかります。

## まとめ

本設計では、NimにおけるCandid用動的データ構造`CandidValue`（仮称）を提案しました。これはNim標準の`JsonNode`と同様のコンセプトで、Candidの全データ型を1つのvariantオブジェクトで表現し、ネスト構造も自由に構築・変更できます。開発者は**文字列キーでRecordにアクセス**でき、JSONに近い感覚で操作可能です。一方で内部的にはCandidの仕様に沿ってフィールド名ハッシュ化や型管理が行われるため、エンコード/デコード処理と整合します。

**設計の要点を振り返ります:**

* NimのJsonNodeに倣い、`kind`でデータ種別を持つvariantオブジェクトで実装。プリミティブ型から複合型まで対応し、OrderedTableやseqを使って構造を保持。
* Candidの各型に対応するケースを用意し、特にRecord, Variant, Option, PrincipalなどJSONにない型も適切に表現。必要に応じ保持するデータ型（例: BigInt, string, tuple）を選定。
* Recordのフィールド名は文字列で保持し、背後で32ビットハッシュIDに変換する機構を用意。衝突は仕様上起きない。アクセス時は透明化し、エンコード時のみIDに変換。
* 操作APIはJsonNodeに近い形で充実させ、`[]`や`add`, `delete`, `getXxx`といった関数を提供。短いコードでネストしたデータの操作が可能。
* JSONライクな文字列変換機能を持ち、人間可読な形式で内容確認が可能。VariantやOptionはシングルキーのオブジェクトで表現し、特殊なキー名（`_..._`）規約で数値IDも区別可能。
* Candidエンコード/デコードとの橋渡しを考慮し、型情報との組み合わせで正確にシリアライズできるよう設計（フィールド名・タグ名を保持、Optionの状態管理等）。デコード時にも型情報を使えば名前つきで構造構築できる。

このように、提案する`CandidValue`データ構造とAPIによって、NimでICPのCanister開発を行う際にCandidメッセージを柔軟かつ直感的に扱えるようになります。JSON的な使い勝手を維持しつつ、Candid固有の要件（フィールドIDや厳密な型）にも対応できる設計となっています。以上の設計を基に実装を行い、テストを通じて使い勝手と正確性を検証していく予定です。

**参考文献:**

* Nim公式 `std/json` ドキュメント（JsonNodeの構造と操作）
* Nim by Example: JSONの利用例（JsonNodeの生成とアクセス）
* DFINITY Internet Computer Candidリファレンスおよびフォーラムの情報（レコードのフィールド名ハッシュと表示方法）

# ===== 使用例とテスト =====

## 命名規則と設計方針

### CandidValue構築の命名規則

本実装では、CandidValueを明示的に構築する際の関数命名を**`newC*`パターンに統一**しています。これにより、以下の利点があります：

1. **一貫性**: すべてのコンストラクタが`newC`で始まる統一された命名
2. **明確性**: 新しいCandidValueインスタンスを生成することが名前から明確
3. **Nim慣例との整合**: Nimでは`new*`パターンがオブジェクト生成の標準的な命名規則

#### サポートされる構築関数

**基本型:**
- `newCNull()` - Null値
- `newCBool(value: bool)` - ブール値
- `newCInt(value: int|BigInt)` - 整数値
- `newCFloat32(value: float32)` - 単精度浮動小数点
- `newCFloat64(value: float)` - 倍精度浮動小数点
- `newCText(value: string)` - テキスト文字列
- `newCBlob(value: seq[uint8])` - バイナリデータ

**構造型:**
- `newCRecord()` - 空のレコード
- `newCArray()` - 空の配列
- `newCVariant(tag: string, value: CandidValue)` - 値ありVariant
- `newCVariant(tag: string)` - 値なしVariant

**Option型:**
- `newCOption(value: CandidValue)` - Some値
- `newCOptionNone()` - None値
- 標準ライブラリの`some(value)`、`none(Type)`も使用可能

**参照型:**
- `newCPrincipal(id: string)` - Principal参照
- `newCFunc(principal: string, method: string)` - 関数参照
- `newCService(principal: string)` - サービス参照

### 廃止された関数

以前のバージョンで提供されていた短縮形の関数は**廃止**されました：

~~`cprincipal()`, `cblob()`, `csome()`, `cnone()`, `cvariant()`, `cfunc()`, `cservice()`, `cnull()`~~

これらは`newC*`関数または標準ライブラリ関数に置き換えられています。

## %* マクロ（candidLit）の使用方法

`%*`マクロ（内部的には`candidLit`マクロ）は、JsonNodeの`%*`マクロと同様に、リテラル構文からCandidValueを簡潔に構築するための機能です。このマクロを使用することで、複雑なCandidデータ構造を直感的に定義できます。

### サポートする構文

#### 基本型
```nim
let data = %* {  # %* マクロを使用
  "name": "Alice",          # Text型
  "age": 30,               # Int型
  "isActive": true,        # Bool型
  "score": 95.5,           # Float64型
  "nothing": newCNull()    # Null型
}
```

#### Principal型
```nim
let user = %* {
  "owner": newCPrincipal("aaaaa-aa"),
  "canister": newCPrincipal("w7x7r-cok77-xa")
}
```

#### Blob型（バイナリデータ）
```nim
let binary = %* {
  "data": newCBlob(@[1u8, 2u8, 3u8, 4u8, 5u8]),
  "signature": newCBlob(@[0x41u8, 0x42u8, 0x43u8])
}
```

#### 配列
```nim
let collections = %* {
  "numbers": [1, 2, 3, 4],
  "names": ["Alice", "Bob", "Charlie"],
  "mixed": [42, "text", true]  # 異なる型の混在も可能
}
```

#### Option型（オプション値）
```nim
let optional = %* {
  "nickname": some("Ali"),        # Some値（標準ライブラリ）
  "middleName": none(string),     # None値（標準ライブラリ）
  "rating": some(5)
}
```

#### Variant型（バリアント・列挙型）
```nim
let variants = %* {
  "status": newCVariant("Active"),                        # 値なしのケース
  "error": newCVariant("Error", newCText("Connection failed")), # 値ありのケース
  "result": newCVariant("Success", newCInt(42))
}
```

#### Func型とService型
```nim
let references = %* {
  "callback": newCFunc("w7x7r-cok77-xa", "handleRequest"),  # Func参照
  "target": newCService("aaaaa-aa")                          # Service参照
}
```

### 複雑なネストした構造の例

```nim
let complexData = %* {
  "user": {
    "id": newCPrincipal("user-123"),
    "profile": {
      "name": "Alice",
      "age": 30,
      "preferences": {
        "theme": newCVariant("Dark"),
        "notifications": some(true)
      }
    },
    "permissions": ["read", "write", "admin"],
    "metadata": newCBlob(@[0x01u8, 0x02u8, 0x03u8])
  },
  "system": {
    "version": "1.0.0",
    "services": [
      newCService("auth-service"),
      newCService("data-service")
    ],
    "callbacks": [
      newCFunc("handler-1", "process"),
      newCFunc("handler-2", "validate")
    ]
  }
}
```

### 変数を使った動的構成

```nim
let userName = "Bob"
let userAge = 25
let isAdmin = true
let userData = @[1u8, 2u8, 3u8]

let dynamicData = %* {
  "name": userName,     # 変数参照
  "age": userAge,
  "isAdmin": isAdmin,
  "data": userData      # seq[uint8]は自動的にBlob型になる
}
```

### データへのアクセス

構築したCandidValueには、JsonNodeと同様の直感的な方法でアクセスできます：

```nim
# レコードフィールドアクセス
echo complexData["user"]["profile"]["name"].getStr()  # "Alice"
echo complexData["user"]["profile"]["age"].getInt()   # 30

# 配列要素アクセス
echo complexData["user"]["permissions"][0].getStr()   # "read"
echo complexData["user"]["permissions"].len()         # 3

# Optionの値チェック
if complexData["user"]["profile"]["preferences"]["notifications"].isSome():
  let value = complexData["user"]["profile"]["preferences"]["notifications"].getOpt()
  echo value.getBool()  # true

# Variantのタグ確認
echo complexData["user"]["profile"]["preferences"]["theme"].variantTag()  # "Dark"

# Principalの取得
echo complexData["user"]["id"].asPrincipal()  # "user-123"

# Funcの詳細取得
echo complexData["system"]["callbacks"][0].funcPrincipal()  # "handler-1"
echo complexData["system"]["callbacks"][0].funcMethod()    # "process"
```

### 動的な変更

```nim
var mutableData = %* {"initial": "value"}

# フィールドの追加・更新
mutableData["newField"] = %* "new value"
mutableData["array"] = %* [1, 2, 3]

# 配列への要素追加
mutableData["array"].add(%* 4)

# フィールドの削除
mutableData.delete("initial")
```

### JSON風文字列への変換

CandidValueは`$`演算子でJSON風の文字列に変換できます：

```nim
let data = %* {
  "text": "Hello",
  "option": some("value"),
  "variant": newCVariant("Tag", newCText("content")),
  "principal": newCPrincipal("aaaaa-aa")
}

echo $data
# 出力例:
# {
#   "text": "Hello",
#   "option": {"some": "value"},
#   "variant": {"Tag": "content"},
#   "principal": "aaaaa-aa"
# }
```

### 型安全性とエラーハンドリング

マクロは compile-time に型チェックを行い、サポートされていない型を使用した場合はコンパイルエラーになります：

```nim
# これはコンパイルエラーになる
# let invalid = %* {"unsupported": someUnsupportedType}
```

実行時の型変換では、不正な型へのアクセス時に例外が発生します：

```nim
let data = %* {"number": 42}
try:
  echo data["number"].getStr()  # IntをStringとして取得しようとする
except ValueError as e:
  echo "Type error: ", e.msg   # "Expected Text, got ckInt"
```

### %* エイリアスについて

`candidLit`マクロは`%*`演算子で使用できます（JSONの`%*`と同じ構文）：

```nim
# 以下は同等
let data1 = candidLit {"key": "value"}
let data2 = %* {"key": "value"}  
```

これにより、JSONの`%*`マクロと同じ感覚でCandidValueを構築できます。実際の使用では、簡潔さのため`%*`を使用することを推奨します。

## まとめ

`%*`マクロ（candidLit）により、以下が実現されました：

1. **直感的な構文**: JsonNode風のリテラル記法
2. **型安全性**: コンパイル時の型チェック
3. **包括的な型サポート**: Candidの全型に対応
4. **ネスト対応**: 任意の深さの構造を構築可能
5. **変数サポート**: 実行時の値も組み込み可能
6. **エラーハンドリング**: 適切な例外処理
7. **統一された命名規則**: `newC*`パターンによる一貫性のあるAPI
8. **JSON互換構文**: `%*`演算子によるJSONと同じ書き心地

### 設計上の利点

新しい命名規則（`newC*`）により、以下の利点が得られています：

- **Nim慣例との整合性**: `newSeq()`, `newTable()`等と一貫した命名
- **明確な意図**: 新しいインスタンスの生成が一目で分かる
- **IntelliSense/補完の改善**: `newC`で始まる関数が一括で見つかる
- **メンテナンス性**: 将来的な拡張時も規則に従いやすい

また、標準ライブラリのOption型（`some()`, `none()`）との併用により、既存のNimコードとの統合もスムーズに行えます。

これにより、Candidデータを扱うNimコードが大幅に簡潔かつ可読性の高いものになります。

## 参考文献
