import ./candid_types
import ./candid_funcs
import std/tables
import std/options

# ================================================================================
# Variant型の定義とコンストラクタ
# ================================================================================

# ===== 基本的なVariant操作 =====

proc newCandidVariantValue*(tag: string, value: CandidValue): CandidValue =
  ## 指定タグ・値のVariantを生成（CandidValue版）
  newCandidVariant(tag, value)

proc newCandidVariantEmpty*(tag: string): CandidValue =
  ## 値を持たないVariantケースを生成
  newCandidVariant(tag, newCandidNull())

# ===== Generic Enum-basedのVariant（新機能） =====

proc newEnumVariant*[T: enum](enumValue: T): CandidValue =
  ## 任意のenum型からVariantを生成
  newCandidVariant($enumValue, newCandidNull())

proc newEnumVariantWithValue*[T: enum](enumValue: T, value: CandidValue): CandidValue =
  ## 任意のenum型と値からVariantを生成
  newCandidVariant($enumValue, value)

# ===== Result型パターンのVariant =====

proc newSuccessVariant*(value: CandidValue): CandidValue =
  ## Success variantを作成
  newCandidVariant("success", value)

proc newSuccessVariant*(value: string): CandidValue =
  ## Success variantを作成（文字列版）
  newCandidVariant("success", newCandidText(value))

proc newSuccessVariant*(value: int): CandidValue =
  ## Success variantを作成（整数版）
  newCandidVariant("success", newCandidInt(value))

proc newErrorVariant*(errorMsg: string): CandidValue =
  ## Error variantを作成
  newCandidVariant("error", newCandidText(errorMsg))

proc newErrorVariant*(value: CandidValue): CandidValue =
  ## Error variantを作成（汎用版）
  newCandidVariant("error", value)

# ===== Option型パターンのVariant =====

proc newSomeVariant*(value: CandidValue): CandidValue =
  ## Some variantを作成
  newCandidVariant("some", value)

proc newSomeVariant*(value: string): CandidValue =
  ## Some variantを作成（文字列版）
  newCandidVariant("some", newCandidText(value))

proc newSomeVariant*(value: int): CandidValue =
  ## Some variantを作成（整数版）
  newCandidVariant("some", newCandidInt(value))

proc newNoneVariant*(): CandidValue =
  ## None variantを作成
  newCandidVariant("none", newCandidNull())

# ===== 高度なVariant操作 =====

proc newNestedVariant*(outerTag: string, innerTag: string, value: CandidValue): CandidValue =
  ## ネストしたVariantを作成
  let innerVariant = newCandidVariant(innerTag, value)
  newCandidVariant(outerTag, innerVariant)

proc newVariantWithRecord*(tag: string, recordFields: Table[string, CandidValue]): CandidValue =
  ## Record値を持つVariantを作成
  let recordValue = newCandidRecord(recordFields)
  newCandidVariant(tag, recordValue)

proc newVariantWithVector*(tag: string, elements: seq[CandidValue]): CandidValue =
  ## Vector値を持つVariantを作成
  let vectorValue = newCandidVec(elements)
  newCandidVariant(tag, vectorValue)

# ===== Variantの値取得と判定 =====

proc getVariantTag*(cv: CandidValue): uint32 =
  ## Variantのタグハッシュを取得
  if cv.kind != ctVariant:
    raise newException(ValueError, "Expected Variant")
  cv.variantVal.tag

proc getVariantValue*(cv: CandidValue): CandidValue =
  ## Variantの値を取得
  if cv.kind != ctVariant:
    raise newException(ValueError, "Expected Variant")
  cv.variantVal.value

proc isVariantTag*(cv: CandidValue, tag: string): bool =
  ## 指定されたタグのVariantかどうか判定
  if cv.kind != ctVariant:
    return false
  cv.variantVal.tag == candidHash(tag)

proc isSuccessVariant*(cv: CandidValue): bool =
  ## Success variantかどうか判定
  isVariantTag(cv, "success")

proc isErrorVariant*(cv: CandidValue): bool =
  ## Error variantかどうか判定
  isVariantTag(cv, "error")

proc isSomeVariant*(cv: CandidValue): bool =
  ## Some variantかどうか判定
  isVariantTag(cv, "some")

proc isNoneVariant*(cv: CandidValue): bool =
  ## None variantかどうか判定
  isVariantTag(cv, "none")

# ===== 型安全な値取得 =====

proc getSuccessValue*(cv: CandidValue): CandidValue =
  ## Success variantの値を取得
  if not isSuccessVariant(cv):
    raise newException(ValueError, "Expected success variant")
  getVariantValue(cv)

proc getErrorValue*(cv: CandidValue): CandidValue =
  ## Error variantの値を取得
  if not isErrorVariant(cv):
    raise newException(ValueError, "Expected error variant")
  getVariantValue(cv)

proc getSomeValue*(cv: CandidValue): CandidValue =
  ## Some variantの値を取得
  if not isSomeVariant(cv):
    raise newException(ValueError, "Expected some variant")
  getVariantValue(cv)

# ===== Enum型のVariant操作 =====

proc getEnumValue*[T: enum](cv: CandidValue, _: type T): T =
  ## Variantから任意のenum型を取得
  if cv.kind != ctVariant:
    raise newException(ValueError, "Expected Variant")
  
  let tagHash = cv.variantVal.tag
  # ハッシュ値から文字列を逆引きするのは困難なので、
  # 全てのenum値を試してハッシュが一致するものを探す
  for enumValue in T:
    if candidHash($enumValue) == tagHash:
      return enumValue
  raise newException(ValueError, "Unknown enum variant for type " & $typeof(T))

proc isEnumVariant*[T: enum](cv: CandidValue, _: type T): bool =
  ## Variantが指定されたenum型かどうか判定
  if cv.kind != ctVariant:
    return false
  let tagHash = cv.variantVal.tag
  for enumValue in T:
    if candidHash($enumValue) == tagHash:
      return true
  return false

# ===== バリデーション関数 =====

proc validateVariant*(cv: CandidValue): bool =
  ## Variantの構造が正しいかバリデーション
  if cv.kind != ctVariant:
    return false
  if cv.variantVal.isNil:
    return false
  if cv.variantVal.value.isNil:
    return false
  return true

proc getVariantInfo*(cv: CandidValue): tuple[tag: uint32, valueKind: CandidType] =
  ## Variantの詳細情報を取得
  if cv.kind != ctVariant:
    raise newException(ValueError, "Expected Variant")
  (tag: cv.variantVal.tag, valueKind: cv.variantVal.value.kind)

# ===== 互換性レイヤー（古いAPIとの互換性保持） =====

# 古いCandidRecord型ベースの関数群は削除し、
# 必要に応じてCandidValue型への移行を促進するため、
# 新しいAPIのみを提供します。
