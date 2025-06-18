## candid_funcs.nim
## 
## Candid型変換関数を集約するモジュール
## ic_*型からCandidValueへの変換とその逆変換を提供
##

import std/tables
import std/options
import std/sequtils

import ./candid_types
import ./ic_principal

# CandidRecordタイプの前方宣言を追加（ic_record.nimから移動）
proc newCNull*(): CandidRecord
proc newCBool*(b: bool): CandidRecord 
proc newCInt*(i: int64): CandidRecord
proc newCInt*(i: int): CandidRecord
proc newCFloat32*(f: float32): CandidRecord
proc newCFloat64*(f: float): CandidRecord
proc newCText*(s: string): CandidRecord
proc newCBlob*(bytes: seq[uint8]): CandidRecord
proc newCRecord*(): CandidRecord
proc newCArray*(): CandidRecord
proc newCPrincipal*(text: string): CandidRecord
proc newCFunc*(principal: string, methodName: string): CandidRecord
proc newCService*(principal: string): CandidRecord
proc newCOptionNone*(): CandidRecord

# ================================================================================
# 基本型からCandidValueへの変換関数
# ================================================================================

proc toCandidValue*(value: bool): CandidValue =
  ## bool型をCandidValueに変換
  CandidValue(kind: ctBool, boolVal: value)

proc toCandidValue*(value: string): CandidValue =
  ## string型をCandidValueに変換
  CandidValue(kind: ctText, textVal: value)

proc toCandidValue*(value: int): CandidValue =
  ## int型をCandidValueに変換
  CandidValue(kind: ctInt, intVal: value)

proc toCandidValue*(value: uint): CandidValue =
  ## uint型をCandidValueに変換
  CandidValue(kind: ctNat, natVal: value)

proc toCandidValue*(value: float32): CandidValue =
  ## float32型をCandidValueに変換
  CandidValue(kind: ctFloat32, float32Val: value)

proc toCandidValue*(value: float64): CandidValue =
  ## float64型をCandidValueに変換
  CandidValue(kind: ctFloat64, float64Val: value)

proc toCandidValue*(value: Principal): CandidValue =
  ## Principal型をCandidValueに変換
  CandidValue(kind: ctPrincipal, principalVal: value)

proc toCandidValue*(value: seq[uint8]): CandidValue =
  ## バイト配列をCandidValueに変換
  CandidValue(kind: ctBlob, blobVal: value)

# ================================================================================
# CandidValueから基本型への変換関数
# ================================================================================

proc toBool*(cv: CandidValue): bool =
  ## CandidValueからbool型に変換
  if cv.kind != ctBool:
    raise newException(ValueError, "Expected bool type")
  cv.boolVal

proc toString*(cv: CandidValue): string =
  ## CandidValueからstring型に変換
  if cv.kind != ctText:
    raise newException(ValueError, "Expected text type")
  cv.textVal

proc toInt*(cv: CandidValue): int =
  ## CandidValueからint型に変換
  if cv.kind != ctInt:
    raise newException(ValueError, "Expected int type")
  cv.intVal

proc toUInt*(cv: CandidValue): uint =
  ## CandidValueからuint型に変換
  if cv.kind != ctNat:
    raise newException(ValueError, "Expected nat type")
  cv.natVal

proc toFloat32*(cv: CandidValue): float32 =
  ## CandidValueからfloat32型に変換
  if cv.kind != ctFloat32:
    raise newException(ValueError, "Expected float32 type")
  cv.float32Val

proc toFloat64*(cv: CandidValue): float64 =
  ## CandidValueからfloat64型に変換
  if cv.kind != ctFloat64:
    raise newException(ValueError, "Expected float64 type")
  cv.float64Val

proc toPrincipal*(cv: CandidValue): Principal =
  ## CandidValueからPrincipal型に変換
  if cv.kind != ctPrincipal:
    raise newException(ValueError, "Expected principal type")
  cv.principalVal

proc toBlob*(cv: CandidValue): seq[uint8] =
  ## CandidValueからバイト配列に変換
  if cv.kind != ctBlob:
    raise newException(ValueError, "Expected blob type")
  cv.blobVal

# ================================================================================
# 型判定ヘルパー関数
# ================================================================================

proc isBool*(cv: CandidValue): bool =
  ## CandidValueがbool型かどうか判定
  cv.kind == ctBool

proc isText*(cv: CandidValue): bool =
  ## CandidValueがtext型かどうか判定
  cv.kind == ctText

proc isInt*(cv: CandidValue): bool =
  ## CandidValueがint型かどうか判定
  cv.kind == ctInt

proc isNat*(cv: CandidValue): bool =
  ## CandidValueがnat型かどうか判定
  cv.kind == ctNat

proc isFloat32*(cv: CandidValue): bool =
  ## CandidValueがfloat32型かどうか判定
  cv.kind == ctFloat32

proc isFloat64*(cv: CandidValue): bool =
  ## CandidValueがfloat64型かどうか判定
  cv.kind == ctFloat64

proc isPrincipal*(cv: CandidValue): bool =
  ## CandidValueがprincipal型かどうか判定
  cv.kind == ctPrincipal

proc isBlob*(cv: CandidValue): bool =
  ## CandidValueがblob型かどうか判定
  cv.kind == ctBlob

proc isNull*(cv: CandidValue): bool =
  ## CandidValueがnull型かどうか判定
  cv.kind == ctNull

# ================================================================================
# CandidRecordとCandidValue間の変換関数（ic_record.nimから移動）
# ================================================================================

proc fromCandidValue*(cv: CandidValue): CandidRecord =
  ## CandidValueをCandidRecordに変換
  case cv.kind:
  of ctNull:
    result = CandidRecord(kind: ckNull)
  of ctBool:
    result = CandidRecord(kind: ckBool, boolVal: cv.boolVal)
  of ctInt:
    result = CandidRecord(kind: ckInt, intVal: cv.intVal.int64)
  of ctFloat32:
    result = CandidRecord(kind: ckFloat32, f32Val: cv.float32Val)
  of ctFloat64:
    result = CandidRecord(kind: ckFloat64, f64Val: cv.float64Val)
  of ctText:
    result = CandidRecord(kind: ckText, strVal: cv.textVal)
  of ctBlob:
    result = CandidRecord(kind: ckBlob, bytesVal: cv.blobVal)
  of ctPrincipal:
    result = CandidRecord(kind: ckPrincipal, principalId: cv.principalVal.value)
  of ctRecord:
    result = CandidRecord(kind: ckRecord)
    result.fields = initOrderedTable[string, CandidValue]()
    for key, value in cv.recordVal.fields:
      result.fields[key] = value
  of ctVariant:
    result = CandidRecord(kind: ckVariant, variantVal: cv.variantVal)
  of ctOpt:
    if cv.optVal.isSome():
      result = CandidRecord(kind: ckOption, optVal: some(fromCandidValue(cv.optVal.get())))
    else:
      result = CandidRecord(kind: ckOption, optVal: none(CandidRecord))
  of ctVec:
    result = CandidRecord(kind: ckArray)
    result.elems = newSeq[CandidRecord]()
    for item in cv.vecVal:
      result.elems.add(fromCandidValue(item))
  of ctFunc:
    result = CandidRecord(kind: ckFunc, funcRef: (principal: cv.funcVal.principal.value, methodName: cv.funcVal.methodName))
  of ctService:
    result = CandidRecord(kind: ckService, serviceId: cv.serviceVal.value)
  else:
    result = CandidRecord(kind: ckNull)  # その他の場合はnullとして扱う

proc toCandidValue*(cr: CandidRecord): CandidValue =
  ## CandidRecordをCandidValueに変換
  case cr.kind:
  of ckNull:
    result = CandidValue(kind: ctNull)
  of ckBool:
    result = CandidValue(kind: ctBool, boolVal: cr.boolVal)
  of ckInt:
    result = CandidValue(kind: ctInt, intVal: cr.intVal.int)
  of ckFloat32:
    result = CandidValue(kind: ctFloat32, float32Val: cr.f32Val)
  of ckFloat64:
    result = CandidValue(kind: ctFloat64, float64Val: cr.f64Val)
  of ckText:
    result = CandidValue(kind: ctText, textVal: cr.strVal)
  of ckBlob:
    result = CandidValue(kind: ctBlob, blobVal: cr.bytesVal)
  of ckRecord:
    # OrderedTableを普通のTableに変換し、ネストしたCandidRecordも正しく変換
    var tableData = initTable[string, CandidValue]()
    for key, value in cr.fields:
      # 値が既にCandidValueの場合はそのまま使用、そうでなければ再帰的に変換
      tableData[key] = value
    result = newCandidRecord(tableData)
  of ckVariant:
    result = CandidValue(kind: ctVariant, variantVal: cr.variantVal)
  of ckOption:
    if cr.optVal.isSome():
      result = CandidValue(kind: ctOpt, optVal: some(cr.optVal.get().toCandidValue()))
    else:
      result = CandidValue(kind: ctOpt, optVal: none(CandidValue))
  of ckPrincipal:
    result = CandidValue(kind: ctPrincipal, principalVal: Principal.fromText(cr.principalId))
  of ckFunc:
    let funcRef = CandidFunc(
      principal: Principal.fromText(cr.funcRef.principal),
      methodName: cr.funcRef.methodName,
      args: @[],
      returns: @[],
      annotations: @[]
    )
    result = CandidValue(kind: ctFunc, funcVal: funcRef)
  of ckService:
    result = CandidValue(kind: ctService, serviceVal: Principal.fromText(cr.serviceId))
  of ckArray:
    let candidValues = cr.elems.map(proc(item: CandidRecord): CandidValue = item.toCandidValue())
    result = CandidValue(kind: ctVec, vecVal: candidValues)

# ================================================================================
# Variant関連の変換関数（重複問題解決のため統合）
# ================================================================================

proc getEnumFromVariant*[T: enum](cv: CandidRecord, _: type T): T =
  ## Variantから任意のenum型を取得（統合版）
  if cv.kind != ckVariant:
    raise newException(ValueError, "Expected Variant")
  
  let tagHash = cv.variantVal.tag
  # ハッシュ値から文字列を逆引きするのは困難なので、
  # 全てのenum値を試してハッシュが一致するものを探す
  for enumValue in T:
    if candidHash($enumValue) == tagHash:
      return enumValue
  raise newException(ValueError, "Unknown enum variant for type " & $typeof(T))

proc getResultVariantFromVariant*[T, E](cv: CandidRecord, _: type ResultVariant[T, E]): ResultVariant[T, E] =
  ## VariantからResultVariantを取得（統合版）
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

proc getOptionVariantFromVariant*[T](cv: CandidRecord, _: type OptionVariant[T]): OptionVariant[T] =
  ## VariantからOptionVariantを取得（統合版）
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

# ================================================================================
# Variant型判定ヘルパー関数
# ================================================================================

proc isEnumVariant*[T: enum](cv: CandidRecord, _: type T): bool =
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

# ================================================================================
# CandidRecordコンストラクタ関数（ic_record.nimから移動）
# ================================================================================

proc newCNull*(): CandidRecord =
  ## Null値を表すCandidRecordを生成
  CandidRecord(kind: ckNull)

proc newCBool*(b: bool): CandidRecord =
  ## ブール値からCandidRecordを生成
  CandidRecord(kind: ckBool, boolVal: b)

proc newCInt*(i: int64): CandidRecord =
  ## 整数からCandidRecordを生成
  CandidRecord(kind: ckInt, intVal: i)

proc newCInt*(i: int): CandidRecord =
  ## 整数からCandidRecordを生成
  CandidRecord(kind: ckInt, intVal: i.int64)

proc newCFloat32*(f: float32): CandidRecord =
  ## 単精度浮動小数点からCandidRecordを生成
  CandidRecord(kind: ckFloat32, f32Val: f)

proc newCFloat64*(f: float): CandidRecord =
  ## 倍精度浮動小数点からCandidRecordを生成
  CandidRecord(kind: ckFloat64, f64Val: f)

proc newCText*(s: string): CandidRecord =
  ## テキストからCandidRecordを生成
  CandidRecord(kind: ckText, strVal: s)

proc newCBlob*(bytes: seq[uint8]): CandidRecord =
  ## バイト列からCandidRecordを生成
  CandidRecord(kind: ckBlob, bytesVal: bytes)

proc newCRecord*(): CandidRecord =
  ## 空のレコードを生成
  CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())

proc newCArray*(): CandidRecord =
  ## 空の配列を生成
  CandidRecord(kind: ckArray, elems: @[])

proc newCPrincipal*(text: string): CandidRecord =
  ## Principal ID文字列からCandidRecordを生成
  CandidRecord(kind: ckPrincipal, principalId: text)

proc newCFunc*(principal: string, methodName: string): CandidRecord =
  ## Func参照を生成
  CandidRecord(kind: ckFunc, funcRef: (principal: principal, methodName: methodName))

proc newCService*(principal: string): CandidRecord =
  ## Service参照を生成
  CandidRecord(kind: ckService, serviceId: principal)

proc newCOptionNone*(): CandidRecord =
  ## Noneを生成
  CandidRecord(kind: ckOption, optVal: none(CandidRecord))

proc newCVariant*(tag: string, val: CandidRecord): CandidRecord =
  ## 指定タグ・値のVariant（CandidRecord版）を生成
  let tagHash = candidHash(tag)
  CandidRecord(kind: ckVariant, variantVal: CandidVariant(tag: tagHash, value: val.toCandidValue()))

proc newCVariant*(tag: string): CandidRecord =
  ## 値を持たないVariantケースを生成
  let tagHash = candidHash(tag)
  CandidRecord(kind: ckVariant, variantVal: CandidVariant(tag: tagHash, value: CandidValue(kind: ctNull)))

# ================================================================================
# as~拡張メソッド（ic_record.nimから移動）
# ================================================================================

proc asBlob*(bytes: seq[uint8]): CandidRecord =
  ## seq[uint8]をBlob型のCandidRecordに変換
  newCBlob(bytes)

proc asText*(s: string): CandidRecord =
  ## stringをText型のCandidRecordに変換
  newCText(s)

proc asBool*(b: bool): CandidRecord =
  ## boolをBool型のCandidRecordに変換
  newCBool(b)

proc asInt*(i: int): CandidRecord =
  ## intをInt型のCandidRecordに変換
  newCInt(i)

proc asInt*(i: int64): CandidRecord =
  ## int64をInt型のCandidRecordに変換
  newCInt(i)

proc asFloat32*(f: float32): CandidRecord =
  ## float32をFloat32型のCandidRecordに変換
  newCFloat32(f)

proc asFloat64*(f: float): CandidRecord =
  ## floatをFloat64型のCandidRecordに変換
  newCFloat64(f)

proc asPrincipal*(text: string): CandidRecord =
  ## 文字列をPrincipal型のCandidRecordに変換
  newCPrincipal(text)

proc asPrincipal*(p: Principal): CandidRecord =
  ## PrincipalをPrincipal型のCandidRecordに変換
  newCPrincipal(p.value)

proc asFunc*(principal: string, methodName: string): CandidRecord =
  ## Func参照を生成
  newCFunc(principal, methodName)

proc asService*(principal: string): CandidRecord =
  ## Service参照を生成
  newCService(principal)

proc asVariant*(tag: string, val: CandidRecord): CandidRecord =
  ## Variant型のCandidRecordを生成
  newCVariant(tag, val)

proc asVariant*(tag: string): CandidRecord =
  ## 値を持たないVariant型のCandidRecordを生成
  newCVariant(tag)

proc asSome*(val: CandidRecord): CandidRecord =
  ## Some値を持つOption型のCandidRecordを生成
  CandidRecord(kind: ckOption, optVal: some(val))

proc asNone*(): CandidRecord =
  ## None値を持つOption型のCandidRecordを生成
  newCOptionNone()

# ================================================================================
# CandidRecord型判定ヘルパー（ic_record.nimから移動）
# ================================================================================

proc isNull*(cv: CandidRecord): bool = cv.kind == ckNull
proc isBool*(cv: CandidRecord): bool = cv.kind == ckBool
proc isInt*(cv: CandidRecord): bool = cv.kind == ckInt
proc isFloat32*(cv: CandidRecord): bool = cv.kind == ckFloat32
proc isFloat64*(cv: CandidRecord): bool = cv.kind == ckFloat64
proc isText*(cv: CandidRecord): bool = cv.kind == ckText
proc isBlob*(cv: CandidRecord): bool = cv.kind == ckBlob
proc isRecord*(cv: CandidRecord): bool = cv.kind == ckRecord
proc isArray*(cv: CandidRecord): bool = cv.kind == ckArray
proc isVariant*(cv: CandidRecord): bool = cv.kind == ckVariant
proc isOption*(cv: CandidRecord): bool = cv.kind == ckOption
proc isPrincipal*(cv: CandidRecord): bool = cv.kind == ckPrincipal
proc isFunc*(cv: CandidRecord): bool = cv.kind == ckFunc
proc isService*(cv: CandidRecord): bool = cv.kind == ckService 