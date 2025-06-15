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
    ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal,
    ctRecord, ctVariant, ctOpt, ctVec, ctBlob,
    ctFunc, ctService, ctQuery, ctOneway, ctCompositeQuery


  # 相互参照する型を同一typeブロック内で定義
  CandidValue* = ref object
    case kind*: CandidType
    of ctNull: discard
    of ctBool: boolVal*: bool
    of ctNat,  ctNat8,  ctNat16,  ctNat32,  ctNat64: natVal*: uint
    of ctInt,  ctInt8,  ctInt16,  ctInt32,  ctInt64: intVal*: int
    of ctFloat32: float32Val*: float32
    of ctFloat64: float64Val*: float64
    of ctText: textVal*: string
    of ctPrincipal: principalVal*: Principal
    of ctRecord: recordVal*: CandidRecord
    of ctVariant: variantVal*: CandidVariant
    of ctOpt: optVal*: Option[CandidValue]
    of ctVec: vecVal*: seq[CandidValue]
    of ctBlob: blobVal*: seq[uint8]
    of ctFunc: funcVal*: tuple[principal: Principal, methodName: string]
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
    ckNull, ckBool, ckInt, ckFloat32, ckFloat64, ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService, ckArray

  CandidRecord* = ref object
    case kind*: CandidRecordKind
    of ckNull:
      discard  # 値を持たない
    of ckBool:
      boolVal*: bool
    of ckInt:
      intVal*: int64  # TODO: BigIntサポート時は BigInt に変更
    of ckFloat32:
      f32Val*: float32
    of ckFloat64:
      f64Val*: float
    of ckText:
      strVal*: string
    of ckBlob:
      bytesVal*: seq[uint8]
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


# ================================================================================
# 共通ユーティリティ関数
# ================================================================================

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
  of ctFloat32: -13
  of ctFloat64: -14
  of ctText: -15
  of ctReserved: -16
  of ctEmpty: -17
  of ctOpt: -18
  of ctVec: -19
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
  of ctNull, ctBool, ctNat, ctInt, ctNat8, ctNat16, ctNat32, ctNat64,
     ctInt8, ctInt16, ctInt32, ctInt64, ctFloat32, ctFloat64,
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
  elif T is byte:
    CandidValue(kind: ctNat8, natVal: uint(value))
  elif T is uint:
    CandidValue(kind: ctNat, natVal: value)
  elif T is float or T is float32:
    CandidValue(kind: ctFloat32, float32Val: value.float32)
  elif T is float64:
    CandidValue(kind: ctFloat64, float64Val: value)
  elif T is string:
    CandidValue(kind: ctText, textVal: value)
  elif T is Principal:
    CandidValue(kind: ctPrincipal, principalVal: value)
  elif T is seq[byte]:
    CandidValue(kind: ctVec, vecVal: value.mapIt(newCandidValue(it)))
  elif T is CandidRecord:
    CandidValue(kind: ctRecord, recordVal: value)
  elif T is CandidVariant:
    CandidValue(kind: ctVariant, variantVal: value)
  elif T is Option[CandidValue]:
    CandidValue(kind: ctOpt, optVal: value)
  elif T is seq[CandidValue]:
    CandidValue(kind: ctVec, vecVal: value)
  elif T is tuple[principal: Principal, methodName: string]:
    CandidValue(kind: ctFunc, funcVal: value)
  elif T is enum:
    # 任意のenum型を文字列として扱う
    CandidValue(kind: ctText, textVal: $value)
  else:
    raise newException(ValueError, "Unsupported type: " & $typeof(value))


# ================================================================================
# Convenience constructors for CandidValue
# ================================================================================

proc newCandidNull*(): CandidValue =
  CandidValue(kind: ctNull)

proc newCandidBool*(value: bool): CandidValue =
  CandidValue(kind: ctBool, boolVal: value)

proc newCandidNat*(value: uint): CandidValue =
  CandidValue(kind: ctNat, natVal: value)

proc newCandidInt*(value: int): CandidValue =
  CandidValue(kind: ctInt, intVal: value)

proc newCandidFloat*(value: float32): CandidValue =
  CandidValue(kind: ctFloat32, float32Val: value)

proc newCandidFloat*(value: float): CandidValue =
  newCandidFloat(value.float32)

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

proc newCandidFunc*(principal: Principal, methodName: string): CandidValue =
  CandidValue(kind: ctFunc, funcVal: (principal: principal, methodName: methodName))

proc newCandidService*(principal: Principal): CandidValue =
  CandidValue(kind: ctService, serviceVal: principal)

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
