import ./candid_types
import ./candid_funcs

# Variant型の定義
type Variant* = object

# ===== 文字列ベースのVariant（既存機能） =====

proc new*(_: type Variant, tag: string, val: CandidRecord): CandidRecord =
  ## 指定タグ・値のVariantを生成
  newCVariant(tag, val)

proc new*(_: type Variant, tag: string): CandidRecord =
  ## 値を持たないVariantケースを生成
  newCVariant(tag)

# ===== Generic Enum-basedのVariant（新機能） =====

proc new*[T: enum](_: type Variant, enumValue: T): CandidRecord =
  ## 任意のenum型からVariantを生成
  newCVariant($enumValue)

proc new*[T, E](_: type Variant, resultVariant: ResultVariant[T, E]): CandidRecord =
  ## ResultVariantからCandidRecordを生成
  if resultVariant.isSuccess:
    when T is CandidRecord:
      newCVariant("success", resultVariant.successValue)
    else:
      newCVariant("success", newCText($resultVariant.successValue))
  else:
    when E is CandidRecord:
      newCVariant("error", resultVariant.errorValue)
    else:
      newCVariant("error", newCText($resultVariant.errorValue))

proc new*[T](_: type Variant, option: OptionVariant[T]): CandidRecord =
  ## OptionVariantからCandidRecordを生成
  if option.hasValue:
    when T is CandidRecord:
      newCVariant("some", option.value)
    else:
      newCVariant("some", newCText($option.value))
  else:
    newCVariant("none")

# ===== 便利な型安全コンストラクタ =====

proc newEnumVariant*[T: enum](enumValue: T): CandidRecord =
  ## 任意のenum型からVariantを作成
  Variant.new(enumValue)

proc newResultVariant*[T, E](resultVariant: ResultVariant[T, E]): CandidRecord =
  ## Result型からVariantを作成
  Variant.new(resultVariant)

proc newOptionVariant*[T](option: OptionVariant[T]): CandidRecord =
  ## Option型からVariantを作成
  Variant.new(option)

# ===== Variantの値取得（generic enum-based） =====

proc getEnum*[T: enum](cv: CandidRecord, _: type T): T =
  ## Variantから任意のenum型を取得
  if cv.kind != ckVariant:
    raise newException(ValueError, "Expected Variant")
  
  let tagHash = cv.variantVal.tag
  # ハッシュ値から文字列を逆引きするのは困難なので、
  # 全てのenum値を試してハッシュが一致するものを探す
  for enumValue in T:
    if candidHash($enumValue) == tagHash:
      return enumValue
  raise newException(ValueError, "Unknown enum variant for type " & $typeof(T))

proc getResultVariant*[T, E](cv: CandidRecord, _: type ResultVariant[T, E]): ResultVariant[T, E] =
  ## VariantからResultVariantを取得
  if cv.kind != ckVariant:
    raise newException(ValueError, "Expected Variant")
  
  let tagHash = cv.variantVal.tag
  case tagHash:
  of candidHash("success"):
    let value = fromCandidValue(cv.variantVal.value)
    when T is CandidRecord:
      return ResultVariant[T, E](isSuccess: true, successValue: value)
    else:
      return ResultVariant[T, E](isSuccess: true, successValue: T(value))
  of candidHash("error"):
    let errValue = fromCandidValue(cv.variantVal.value)
    when E is CandidRecord:
      return ResultVariant[T, E](isSuccess: false, errorValue: errValue)
    else:
      return ResultVariant[T, E](isSuccess: false, errorValue: E(errValue))
  else:
    raise newException(ValueError, "Unknown Result variant tag")

proc getOptionVariant*[T](cv: CandidRecord, _: type OptionVariant[T]): OptionVariant[T] =
  ## VariantからOptionVariantを取得
  if cv.kind != ckVariant:
    raise newException(ValueError, "Expected Variant")
  
  let tagHash = cv.variantVal.tag
  case tagHash:
  of candidHash("some"):
    let value = fromCandidValue(cv.variantVal.value)
    when T is CandidRecord:
      return OptionVariant[T](hasValue: true, value: value)
    else:
      return OptionVariant[T](hasValue: true, value: T(value))
  of candidHash("none"):
    return OptionVariant[T](hasValue: false)
  else:
    raise newException(ValueError, "Unknown Option variant tag")

# ===== 型判定ヘルパー =====

proc isEnum*[T: enum](cv: CandidRecord, _: type T): bool =
  ## Variantが指定されたenum型かどうか判定
  if cv.kind != ckVariant:
    return false
  let tagHash = cv.variantVal.tag
  for enumValue in T:
    if candidHash($enumValue) == tagHash:
      return true
  return false

proc isResultVariant*(cv: CandidRecord): bool =
  ## VariantがResult型かどうか判定
  if cv.kind != ckVariant:
    return false
  let tagHash = cv.variantVal.tag
  tagHash == candidHash("success") or tagHash == candidHash("error")

proc isOptionVariant*(cv: CandidRecord): bool =
  ## VariantがOption型かどうか判定
  if cv.kind != ckVariant:
    return false
  let tagHash = cv.variantVal.tag
  tagHash == candidHash("some") or tagHash == candidHash("none")
