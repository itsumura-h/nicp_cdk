import std/options
import std/tables

type
  CandidRecordKind* = enum
    ckNull, ckBool, ckInt, ckFloat32, ckFloat64, ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService, ckArray

  CandidVariant* = object
    ## Variant型の値を保持するオブジェクト
    tag*: string         ## Variantのタグ名
    value*: CandidValue  ## Variantの保持する値

  CandidValue* = ref object
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
      optVal*: Option[CandidValue]
    of ckPrincipal:
      principalId*: string
    of ckFunc:
      funcRef*: tuple[principal: string, methodName: string]
    of ckService:
      serviceId*: string
    of ckArray:
      elems*: seq[CandidValue]