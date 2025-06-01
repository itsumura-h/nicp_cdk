import std/options
import std/tables
import ./ic_principal


#---- Candid 型タグの定義 ----
type
  CandidType* = enum
    ctNull, ctBool, ctNat, ctInt,
    ctNat8, ctNat16, ctNat32, ctNat64,
    ctInt8, ctInt16, ctInt32, ctInt64,
    ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal,
    ctRecord, ctVariant, ctOpt, ctVec,
    ctFunc, ctService, ctQuery, ctOneway, ctCompositeQuery

  # 相互参照する型を同一typeブロック内で定義
  CandidValue* = ref object
    case kind*: CandidType
    of ctNull: discard
    of ctBool: boolVal*: bool
    of ctNat,  ctNat8,  ctNat16,  ctNat32,  ctNat64: natVal*: Natural
    of ctInt,  ctInt8,  ctInt16,  ctInt32,  ctInt64: intVal*: int
    of ctFloat32: float32Val*: float32
    of ctFloat64: float64Val*: float64
    of ctText: textVal*: string
    of ctPrincipal: principalVal*: Principal
    of ctRecord: recordVal*: CandidRecord
    of ctVariant: variantVal*: CandidVariant
    of ctOpt: optVal*: Option[CandidValue]
    of ctVec: vecVal*: seq[CandidValue]
    of ctFunc: funcVal*: tuple[principal: Principal, methodName: string]
    of ctService: serviceVal*: Principal
    of ctReserved, ctEmpty: discard
    of ctQuery: discard
    of ctOneway: discard
    of ctCompositeQuery: discard

  CandidRecord* = ref object
    values*: Table[uint32, CandidValue]

  CandidVariant* = ref object
    tag*: uint32
    value*: CandidValue


proc newCandidValue*[T](value: T): CandidValue =
  when T is bool:
    CandidValue(kind: ctBool, boolVal: value)
  elif T is int:
    CandidValue(kind: ctInt, intVal: value)
  elif T is byte:
    CandidValue(kind: ctNat8, natVal: Natural(value))
  elif T is Natural:
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
  else:
    raise newException(ValueError, "Unsupported type: " & $typeof(value))


# フィールド名から32bitハッシュを計算（Candidの仕様に従う）
proc candidHash*(name: string): uint32 =
  ## Candid仕様のフィールドハッシュ計算
  var h: uint32 = 0
  for c in name:
    h = h * 223 + uint32(ord(c))
  return h


# ================================================================================
# Convenience constructors for CandidValue
# ================================================================================

proc newCandidNull*(): CandidValue =
  CandidValue(kind: ctNull)

proc newCandidBool*(value: bool): CandidValue =
  CandidValue(kind: ctBool, boolVal: value)

proc newCandidNat*(value: Natural): CandidValue =
  CandidValue(kind: ctNat, natVal: value)

proc newCandidInt*(value: int): CandidValue =
  CandidValue(kind: ctInt, intVal: value)

proc newCandidFloat*(value: float32): CandidValue =
  CandidValue(kind: ctFloat32, float32Val: value)

proc newCandidFloat*(value: float): CandidValue =
  newCandidFloat(value.float32)

proc newCandidText*(value: string): CandidValue =
  CandidValue(kind: ctText, textVal: value)

proc newCandidPrincipal*(value: Principal): CandidValue =
  CandidValue(kind: ctPrincipal, principalVal: value)

proc newCandidRecord*(values: Table[string, CandidValue]): CandidValue =
  var record = CandidRecord(values: initTable[uint32, CandidValue]())
  for key, value in values:
    record.values[candidHash(key)] = newCandidValue(value)
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
