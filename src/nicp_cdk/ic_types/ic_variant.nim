import ./candid_types
import ./ic_record

# Variant型の定義
type Variant* = object

# Variant型のコンストラクタ関数
proc new*(_: type Variant, tag: string, val: CandidRecord): CandidRecord =
  ## 指定タグ・値のVariantを生成
  newCVariant(tag, val)


proc new*(_: type Variant, tag: string): CandidRecord =
  ## 値を持たないVariantケースを生成
  newCVariant(tag)
