import std/options
import std/tables
import std/macros
import std/sequtils
import std/strutils
import std/algorithm
import ./ic_principal


#---- Candid 型タグの定義 ----
type
  CandidType* = enum
    ctNull, ctBool, ctNat, ctInt,
    ctNat8, ctNat16, ctNat32, ctNat64,
    ctInt8, ctInt16, ctInt32, ctInt64,
    ctFloat, ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal,
    ctRecord, ctVariant, ctOpt, ctVec, ctBlob,
    ctFunc, ctService, ctQuery, ctOneway, ctCompositeQuery


  # 相互参照する型を同一typeブロック内で定義
  CandidValue* = ref object
    case kind*: CandidType
    of ctNull: discard
    of ctBool: boolVal*: bool
    of ctNat,  ctNat8,  ctNat16,  ctNat32,  ctNat64: natVal*: uint
    of ctInt: intVal*: int
    of ctInt8: int8Val*: int8
    of ctInt16: int16Val*: int16
    of ctInt32: int32Val*: int32
    of ctInt64: int64Val*: int64
    of ctFloat: floatVal*: float
    of ctFloat32: float32Val*: float32
    of ctFloat64: float64Val*: float64
    of ctText: textVal*: string
    of ctPrincipal: principalVal*: Principal
    of ctRecord: recordVal*: CandidRecord
    of ctVariant: variantVal*: CandidVariant
    of ctOpt: optVal*: Option[CandidValue]
    of ctVec: vecVal*: seq[CandidValue]
    of ctBlob: blobVal*: seq[uint8]
    of ctFunc: funcVal*: CandidFunc
    of ctService: serviceVal*: Principal
    of ctReserved, ctEmpty: discard
    of ctQuery: discard
    of ctOneway: discard
    of ctCompositeQuery: discard

  # ==================================================
  # CandidVariant
  # ==================================================
  CandidVariant* = ref object
    tag*: uint32
    value*: CandidValue

  # Generic Result type variant
  ResultVariant*[T, E] = object
    case isSuccess*: bool
    of true:
      successValue*: T
    of false:
      errorValue*: E

  # Option-like variant
  OptionVariant*[T] = object
    case hasValue*: bool
    of true:
      value*: T
    of false:
      discard

  # ==================================================
  # CandidRecord
  # ==================================================
  CandidRecordKind* = enum
    ckNull, ckBool,
    ckInt, ckInt8, ckInt16, ckInt32, ckInt64, 
    ckNat, ckNat8, ckNat16, ckNat32, ckNat64,
    ckFloat, ckFloat32, ckFloat64,
    ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService, ckArray

  CandidRecord* {.acyclic, inheritable.} = ref object
    case kind*: CandidRecordKind
    of ckNull:
      discard  # 値を持たない
    of ckBool:
      boolVal*: bool
    of ckInt:
      intVal*: int
    of ckInt8:
      int8Val*: int8
    of ckInt16:
      int16Val*: int16
    of ckInt32:
      int32Val*: int32
    of ckInt64:
      int64Val*: int64
    of ckNat:
      natVal*: uint
    of ckNat8:
      nat8Val*: uint8
    of ckNat16:
      nat16Val*: uint16
    of ckNat32:
      nat32Val*: uint32
    of ckNat64:
      nat64Val*: uint64
    of ckFloat:
      fVal*: float
    of ckFloat32:
      f32Val*: float32
    of ckFloat64:
      f64Val*: float
    of ckText:
      strVal*: string
    of ckBlob:
      blobVal*: seq[uint8]
    of ckRecord:
      fields*: OrderedTable[string, CandidValue]
    of ckVariant:
      variantVal*: CandidVariant
    of ckOption:
      optVal*: Option[CandidRecord]
    of ckPrincipal:
      principalId*: string
    of ckFunc:
      funcRef*: tuple[principal: string, methodName: string]
    of ckService:
      serviceId*: string
    of ckArray:
      elems*: seq[CandidRecord]

  # 既存のCandidFunc型定義を拡張
  CandidFunc* = ref object
    principal*: Principal
    methodName*: string
    args*: seq[CandidType]         # 引数の型リスト
    returns*: seq[CandidType]      # 戻り値の型リスト  
    annotations*: seq[string]      # query, oneway, composite_queryなど


# ================================================================================
# 共通ユーティリティ関数
# ================================================================================
proc `$`*(value: CandidValue): string =
  ## CandidValue を文字列に変換する
  case value.kind:
  of ctNull:
    result = "null"
  of ctBool:
    result = $value.boolVal
  of ctNat, ctNat8, ctNat16, ctNat32, ctNat64:
    result = $value.natVal
  of ctInt:
    result = $value.intVal
  of ctInt8:
    result = $value.int8Val
  of ctInt16:
    result = $value.int16Val
  of ctInt32:
    result = $value.int32Val
  of ctInt64:
    result = $value.int64Val
  of ctFloat:
    result = $value.floatVal
  of ctFloat32:
    result = $value.float32Val
  of ctFloat64:
    result = $value.float64Val
  of ctText:
    result = "\"" & value.textVal & "\""
  of ctPrincipal:
    result = "principal \"" & $value.principalVal & "\""
  of ctBlob:
    result = "blob \"" & value.blobVal.mapIt(it.toHex()).join("") & "\""
  of ctRecord:
    result = "record {"
    var first = true
    for fieldName, fieldValue in value.recordVal.fields:
      if not first:
        result.add("; ")
      result.add(fieldName & " = " & $fieldValue)
      first = false
    result.add("}")
  of ctVariant:
    result = "variant {" & $value.variantVal.tag & " = " & $value.variantVal.value & "}"
  of ctOpt:
    if value.optVal.isSome:
      result = "opt " & $value.optVal.get()
    else:
      result = "null"
  of ctVec:
    result = "vec ["
    for i, elem in value.vecVal:
      if i > 0:
        result.add(", ")
      result.add($elem)
    result.add("]")
  of ctFunc:
    result = "func \"" & $value.funcVal.principal & "\"." & value.funcVal.methodName
    if value.funcVal.annotations.len > 0:
      result.add(" " & value.funcVal.annotations.join(" "))
  of ctService:
    result = "service \"" & $value.serviceVal & "\""
  of ctReserved:
    result = "reserved"
  of ctEmpty:
    result = "empty"
  of ctQuery:
    result = "query"
  of ctOneway:
    result = "oneway"  
  of ctCompositeQuery:
    result = "composite_query"


proc toString*(data: seq[byte]): string =
  return data.mapIt(it.toHex()).join("")

proc stringToBytes*(s: string): seq[byte] =
  # 2文字ずつバイト列に変換
  for i in countup(0, s.len-1, 2):
    result.add(byte(s[i..i+1].parseHexInt()))

proc ptrToUint32*(p: pointer): uint32 =
  return cast[uint32](p)

proc ptrToInt*(p: pointer): int =
  return cast[int](p)

proc typeCodeFromCandidType*(candidType: CandidType): int =
  ## CandidTypeから型コードを取得
  case candidType:
  of ctNull: -1
  of ctBool: -2
  of ctNat: -3
  of ctInt: -4
  of ctNat8: -5
  of ctNat16: -6
  of ctNat32: -7
  of ctNat64: -8
  of ctInt8: -9
  of ctInt16: -10
  of ctInt32: -11
  of ctInt64: -12
  of ctFloat: -13  # floatはfloat32として扱う
  of ctFloat32: -13
  of ctFloat64: -14
  of ctText: -15
  of ctReserved: -16
  of ctEmpty: -17
  of ctOpt: -18
  of ctVec: -19
  of ctBlob: -19  # Blobは実際にはvec nat8として扱われる
  of ctRecord: -20
  of ctVariant: -21
  of ctFunc: -22
  of ctService: -23
  of ctPrincipal: -24
  else:
    raise newException(ValueError, "Unsupported type for encoding: " & $candidType)

proc isPrimitiveType*(candidType: CandidType): bool =
  ## 基本型かどうかを判定
  case candidType:
  of ctNull, ctBool,
    ctInt, ctInt8, ctInt16, ctInt32, ctInt64,
    ctNat, ctNat8, ctNat16, ctNat32, ctNat64,
    ctFloat, ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal:
    return true
  else:
    return false

# フィールド名から32bitハッシュを計算（Candidの仕様に従う）
proc candidHash*(name: string): uint32 =
  ## Candid仕様のフィールドハッシュ計算
  var h: uint32 = 0
  for c in name:
    h = h * 223 + uint32(ord(c))
  return h


# ================================================================================
# 既存のプロシージャは継続
# ================================================================================

proc newCandidValue*[T](value: T): CandidValue =
  when T is bool:
    CandidValue(kind: ctBool, boolVal: value)
  elif T is int:
    CandidValue(kind: ctInt, intVal: value)
  elif T is int8:
    CandidValue(kind: ctInt8, int8Val: value)
  elif T is int16:
    CandidValue(kind: ctInt16, int16Val: value)
  elif T is int32:
    CandidValue(kind: ctInt32, int32Val: value)
  elif T is int64:
    CandidValue(kind: ctInt64, int64Val: value)
  elif T is byte:
    CandidValue(kind: ctNat8, natVal: uint(value))
  elif T is uint16:
    CandidValue(kind: ctNat16, natVal: uint(value))
  elif T is uint32:
    CandidValue(kind: ctNat32, natVal: uint(value))
  elif T is uint64:
    CandidValue(kind: ctNat64, natVal: uint(value))
  elif T is uint:
    CandidValue(kind: ctNat, natVal: value)
  elif T is float64:
    CandidValue(kind: ctFloat64, float64Val: value)
  elif T is float or T is float32:
    CandidValue(kind: ctFloat32, float32Val: value.float32)
  elif T is float:
    CandidValue(kind: ctFloat, floatVal: value)
  elif T is string:
    CandidValue(kind: ctText, textVal: value)
  elif T is Principal:
    CandidValue(kind: ctPrincipal, principalVal: value)
  elif T is seq[uint8]:
    CandidValue(kind: ctBlob, blobVal: value)
  elif T is seq[seq[uint8]]:
    # vec blob型のサポート - seq[uint8]要素をそれぞれblobとして処理
    var vecElements = newSeq[CandidValue]()
    for blob in value:
      vecElements.add(CandidValue(kind: ctBlob, blobVal: blob))
    CandidValue(kind: ctVec, vecVal: vecElements)
  elif T is seq[byte]:
    CandidValue(kind: ctVec, vecVal: value.mapIt(newCandidValue(it)))
  elif T is CandidRecord:
    CandidValue(kind: ctRecord, recordVal: value)
  elif T is CandidVariant:
    CandidValue(kind: ctVariant, variantVal: value)
  elif T is Option[CandidValue]:
    CandidValue(kind: ctOpt, optVal: value)
  elif T is Option[Principal]:
    # Option[Principal]型のサポート
    if value.isSome():
      CandidValue(kind: ctOpt, optVal: some(newCandidValue(value.get())))
    else:
      CandidValue(kind: ctOpt, optVal: none(CandidValue))
  elif T is seq[CandidValue]:
    CandidValue(kind: ctVec, vecVal: value)
  elif T is tuple[principal: Principal, methodName: string]:
    CandidValue(kind: ctFunc, funcVal: value)
  elif T is enum:
    # Enum型をVariant型として変換（Enum名のVariantとしてnull値を持つ）
    newCandidVariant($value, newCandidNull())
  else:
    raise newException(ValueError, "Unsupported type: " & $typeof(value))


# ================================================================================
# Convenience constructors for CandidValue
# ================================================================================

proc newCandidNull*(): CandidValue =
  CandidValue(kind: ctNull)

proc newCandidBool*(value: bool): CandidValue =
  CandidValue(kind: ctBool, boolVal: value)

proc newCandidInt*(value: int): CandidValue =
  CandidValue(kind: ctInt, intVal: value)

proc newCandidInt8*(value: int8): CandidValue =
  CandidValue(kind: ctInt8, int8Val: value)

proc newCandidInt16*(value: int16): CandidValue =
  CandidValue(kind: ctInt16, int16Val: value)

proc newCandidInt32*(value: int32): CandidValue =
  CandidValue(kind: ctInt32, int32Val: value)

proc newCandidInt64*(value: int64): CandidValue =
  CandidValue(kind: ctInt64, int64Val: value)

proc newCandidNat*(value: uint): CandidValue =
  CandidValue(kind: ctNat, natVal: value)

proc newCandidNat8*(value: uint8): CandidValue =
  CandidValue(kind: ctNat8, natVal: uint(value))

proc newCandidNat16*(value: uint16): CandidValue =
  CandidValue(kind: ctNat16, natVal: uint(value))

proc newCandidNat32*(value: uint32): CandidValue =
  CandidValue(kind: ctNat32, natVal: uint(value))

proc newCandidNat64*(value: uint64): CandidValue =
  CandidValue(kind: ctNat64, natVal: uint(value))

proc newCandidFloat*(value: float): CandidValue =
  CandidValue(kind: ctFloat, floatVal: value)

proc newCandidFloat32*(value: float32): CandidValue =
  CandidValue(kind: ctFloat32, float32Val: value)

proc newCandidFloat64*(value: float64): CandidValue =
  CandidValue(kind: ctFloat64, float64Val: value)

proc newCandidText*(value: string): CandidValue =
  CandidValue(kind: ctText, textVal: value)

proc newCandidBlob*(value: seq[uint8]): CandidValue =
  CandidValue(kind: ctBlob, blobVal: value)

proc newCandidPrincipal*(value: Principal): CandidValue =
  CandidValue(kind: ctPrincipal, principalVal: value)

proc newCandidRecord*(values: Table[string, CandidValue]): CandidValue =
  var record = CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())
  for key, value in values:
    record.fields[key] = value
  CandidValue(kind: ctRecord, recordVal: record)

proc newCandidVariant*(tag: string, value: CandidValue): CandidValue =
  let variant = CandidVariant(tag: candidHash(tag), value: value)
  CandidValue(kind: ctVariant, variantVal: variant)

proc newCandidOpt*(value: Option[CandidValue]): CandidValue =
  CandidValue(kind: ctOpt, optVal: value)

proc newCandidVec*(values: seq[CandidValue]): CandidValue =
  CandidValue(kind: ctVec, vecVal: values)

proc newCandidFunc*(principal: Principal, methodName: string, args: seq[CandidType] = @[], returns: seq[CandidType] = @[], annotations: seq[string] = @[]): CandidValue =
  let funcRef = CandidFunc(
    principal: principal,
    methodName: methodName,
    args: args,
    returns: returns,
    annotations: annotations
  )
  CandidValue(kind: ctFunc, funcVal: funcRef)

proc newCandidService*(principal: Principal): CandidValue =
  CandidValue(kind: ctService, serviceVal: principal)

proc newCandidEmpty*(): CandidValue =
  ## Creates a CandidValue of kind ctEmpty.
  CandidValue(kind: ctEmpty)

# ================================================================================
# Generic enum-based variant constructors
# ================================================================================

proc newCandidVariant*[T: enum](enumValue: T): CandidValue =
  ## 任意のenum型からvariantを作成
  newCandidVariant($enumValue, newCandidNull())

proc newCandidVariant*[T, E](resultVariant: ResultVariant[T, E]): CandidValue =
  ## ResultVariantからCandidVariantを作成
  if resultVariant.isSuccess:
    when T is CandidValue:
      newCandidVariant("success", resultVariant.successValue)
    else:
      newCandidVariant("success", newCandidValue(resultVariant.successValue))
  else:
    when E is CandidValue:
      newCandidVariant("error", resultVariant.errorValue)
    else:
      newCandidVariant("error", newCandidValue(resultVariant.errorValue))

proc newCandidVariant*[T](option: OptionVariant[T]): CandidValue =
  ## OptionVariantからCandidVariantを作成
  if option.hasValue:
    when T is CandidValue:
      newCandidVariant("some", option.value)
    else:
      newCandidVariant("some", newCandidValue(option.value))
  else:
    newCandidVariant("none", newCandidNull())

# ================================================================================
# Enum-based variant helper constructors
# ================================================================================

# proc success*[T](value: T): ResultVariant[T, string] =
#   ## Successな結果を作成
#   ResultVariant[T, string](isSuccess: true, successValue: value)

# proc error*[T](err: string): ResultVariant[T, string] =
#   ## Errorな結果を作成
#   ResultVariant[T, string](isSuccess: false, errorValue: err)

# proc some*[T](value: T): OptionVariant[T] =
#   ## Some値を作成
#   OptionVariant[T](hasValue: true, value: value)

# proc none*[T](_: type T): OptionVariant[T] =
#   ## None値を作成
#   OptionVariant[T](hasValue: false)

# ================================================================================
# Generic enum parsing helpers
# ================================================================================

proc parseEnum*[T: enum](s: string, _: type T): T =
  ## 文字列から任意のenum型を解析
  for enumValue in T:
    if $enumValue == s:
      return enumValue
  raise newException(ValueError, "Unknown enum value: " & s & " for type " & $typeof(T))

# ================================================================================
# Enum型とVariant型の相互変換機能
# ================================================================================

proc getEnumValue*[T: enum](cv: CandidValue, enumType: typedesc[T]): T =
  ## CandidValueからEnum値を取得（Variant型から変換）
  if cv.kind != ctVariant:
    raise newException(ValueError, "CandidValue is not a variant type")
  
  # Variantのタグ（ハッシュ値）から対応するEnum値を検索
  let variant = cv.variantVal
  # タグハッシュから文字列を逆算するのは困難なため、全Enum値と比較
  for enumValue in T:
    let expectedHash = candidHash($enumValue)
    if variant.tag == expectedHash:
      return enumValue
  
  # 見つからない場合は文字列による比較も試行
  raise newException(ValueError, 
    "Cannot convert Variant tag " & $variant.tag & " to enum type " & $typeof(T) & ". " &
    "Available enum values: " & @[T.low..T.high].mapIt($it).join(", "))

proc validateEnumType*[T: enum](enumType: typedesc[T]) =
  ## Enum型の制約をチェック（{.pure.} pragma付きかどうかなど）
  # 注意: Nimのコンパイル時情報では{.pure.}の検出は困難
  # 実行時チェックとして、連続性や重複をチェック
  var enumValues: seq[string] = @[]
  for enumValue in T:
    let enumStr = $enumValue
    if enumStr in enumValues:
      raise newException(ValueError, 
        "Duplicate enum value '" & enumStr & "' found in type " & $typeof(T) & ". " &
        "Enum types for Candid conversion should have unique string representations.")
    enumValues.add(enumStr)

proc isEnumCompatible*[T: enum](enumType: typedesc[T]): bool =
  ## Enum型がCandid変換に対応しているかチェック
  try:
    validateEnumType(enumType)
    return true
  except ValueError:
    return false

# CandidFunc型のヘルパー関数を追加
proc newSimpleFunc*(principal: Principal, methodName: string): CandidFunc =
  ## 引数・戻り値なしのシンプルなfunc参照を作成
  CandidFunc(
    principal: principal,
    methodName: methodName,
    args: @[],
    returns: @[],
    annotations: @[]
  )

proc newQueryFunc*(principal: Principal, methodName: string, returns: seq[CandidType] = @[]): CandidFunc =
  ## Query annotationを持つfunc参照を作成
  CandidFunc(
    principal: principal,
    methodName: methodName,
    args: @[],
    returns: returns,
    annotations: @["query"]
  )

proc newUpdateFunc*(principal: Principal, methodName: string, args: seq[CandidType] = @[], returns: seq[CandidType] = @[]): CandidFunc =
  ## Update func参照を作成（annotation無し）
  return CandidFunc(
    principal: principal,
    methodName: methodName,
    args: args,
    returns: returns,
    annotations: @[]
  )

proc isQuery*(f: CandidFunc): bool =
  ## func参照がquery関数かどうか判定
  "query" in f.annotations

proc isOneway*(f: CandidFunc): bool =
  ## func参照がoneway関数かどうか判定
  "oneway" in f.annotations

proc newCandidVecBlob*(blobs: seq[seq[uint8]]): CandidValue =
  ## seq[seq[uint8]]からvec blob型のCandidValueを作成
  var vecElements = newSeq[CandidValue]()
  for blob in blobs:
    vecElements.add(CandidValue(kind: ctBlob, blobVal: blob))
  CandidValue(kind: ctVec, vecVal: vecElements)

# ================================================================================
# Vec/Blob統一処理 - 動的型変換API
# ================================================================================

proc getItems*(cv: CandidValue): seq[CandidValue] =
  ## CandidValueからVec型として要素を取得（統一内部表現から変換）
  if cv.kind != ctVec:
    raise newException(ValueError, "CandidValue is not a vector type, got: " & $cv.kind)
  
  # 統一内部表現のvecValから直接返す
  return cv.vecVal

proc getBlob*(cv: CandidValue): seq[uint8] =
  ## CandidValueからBlob型として要素を取得（統一内部表現から変換）
  if cv.kind != ctVec:
    raise newException(ValueError, "CandidValue is not a vector type (or blob), got: " & $cv.kind)
  
  # 統一内部表現から uint8 seq に変換
  var blobData = newSeq[uint8]()
  for item in cv.vecVal:
    if item.kind == ctNat8:
      blobData.add(uint8(item.natVal))
    else:
      raise newException(ValueError, "Vector contains non-nat8 element, cannot convert to blob. Element type: " & $item.kind)
  
  return blobData

proc asBlobValue*(data: seq[uint8]): CandidValue =
  ## seq[uint8]を明示的にBlob用CandidValueとして作成（Record挿入用）
  # 統一内部表現として vec nat8 で作成
  var vecElements = newSeq[CandidValue]()
  for byteVal in data:
    vecElements.add(CandidValue(kind: ctNat8, natVal: uint(byteVal)))
  
  var result = CandidValue(kind: ctVec, vecVal: vecElements)
  # Blob意図の記録用にメタ情報を設定（将来の拡張用）
  # 注意: 現在はkind=ctVecで統一、実際の型判定はAPI使用時
  return result

proc asSeqValue*[T](data: seq[T]): CandidValue =
  ## seq[T]を明示的にVector用CandidValueとして作成（Record挿入用）
  var vecElements = newSeq[CandidValue]()
  for item in data:
    vecElements.add(newCandidValue(item))
  
  return CandidValue(kind: ctVec, vecVal: vecElements)

proc isVecNat8*(cv: CandidValue): bool =
  ## CandidValueがvec nat8型かどうか判定（統一内部表現での判定）
  if cv.kind != ctVec:
    return false
  
  # すべての要素がnat8かチェック
  for item in cv.vecVal:
    if item.kind != ctNat8:
      return false
  
  return true

proc canConvertToBlob*(cv: CandidValue): bool =
  ## CandidValueがBlob型に変換可能かチェック
  return isVecNat8(cv)
