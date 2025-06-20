import std/options
import ./ic_types/candid_types
import ./ic_types/candid_message/candid_decode
import ./ic_types/ic_principal
import ./ic_types/ic_record
import ./ic0/ic0


type Request* = object
  values: seq[CandidValue]

proc new*(_:type Request): Request =
  let n = ic0_msg_arg_data_size()
  var data = newSeq[byte](n)
  ic0_msg_arg_data_copy(ptrToInt(addr data[0]), 0, n)
  # let values = parseCandidArgs(data)
  let decodedResult = decodeCandidMessage(data)
  return Request(values: decodedResult.values)


# 指定されたインデックスの引数を bool として取得する
proc getBool*(self:Request, index:int): bool =
  ## Get the argument at the specified index as a bool
  assert self.values[index].kind == ctBool
  return self.values[index].boolVal


proc getNat*(self:Request, index:int): uint =
  ## Get the argument at the specified index as a nat
  assert self.values[index].kind == ctNat
  return self.values[index].natVal


proc getNat8*(self:Request, index:int): uint8 =
  ## Get the argument at the specified index as a nat8
  assert self.values[index].kind == ctNat8
  return self.values[index].natVal.uint8


proc getNat16*(self:Request, index:int): uint16 =
  ## Get the argument at the specified index as a nat16
  assert self.values[index].kind == ctNat16
  return self.values[index].natVal.uint16


proc getNat32*(self:Request, index:int): uint32 =
  ## Get the argument at the specified index as a nat32
  assert self.values[index].kind == ctNat32
  return self.values[index].natVal.uint32


proc getNat64*(self:Request, index:int): uint64 =
  ## Get the argument at the specified index as a nat64
  assert self.values[index].kind == ctNat64
  return self.values[index].natVal.uint64


# 指定されたインデックスの引数を int として取得する
proc getInt*(self:Request, index:int): int =
  ## Get the argument at the specified index as an int
  assert self.values[index].kind == ctInt
  return self.values[index].intVal


# 指定されたインデックスの引数を int8 として取得する
proc getInt8*(self:Request, index:int): int8 =
  ## Get the argument at the specified index as an int8
  assert self.values[index].kind == ctInt8
  return self.values[index].int8Val


# 指定されたインデックスの引数を int16 として取得する
proc getInt16*(self:Request, index:int): int16 =
  ## Get the argument at the specified index as an int16
  assert self.values[index].kind == ctInt16
  return self.values[index].int16Val


# 指定されたインデックスの引数を int32 として取得する
proc getInt32*(self:Request, index:int): int32 =
  ## Get the argument at the specified index as an int32
  assert self.values[index].kind == ctInt32
  return self.values[index].int32Val


# 指定されたインデックスの引数を int64 として取得する
proc getInt64*(self:Request, index:int): int64 =
  ## Get the argument at the specified index as an int64
  assert self.values[index].kind == ctInt64
  return self.values[index].int64Val



# 指定されたインデックスの引数を float32 として取得する
proc getFloat*(self:Request, index:int): float32 =
  ## Get the argument at the specified index as a float32
  assert self.values[index].kind == ctFloat32
  return self.values[index].float32Val


# 指定されたインデックスの引数を float32 として取得する
proc getFloat32*(self:Request, index:int): float32 =
  ## Get the argument at the specified index as a float32
  assert self.values[index].kind == ctFloat32
  return self.values[index].float32Val


# 指定されたインデックスの引数を float64 として取得する
proc getFloat64*(self:Request, index:int): float64 =
  ## Get the argument at the specified index as a float64
  assert self.values[index].kind == ctFloat64
  return self.values[index].float64Val


# 指定されたインデックスの引数を文字列として取得する
proc getStr*(self:Request, index:int): string =
  ## Get the argument at the specified index as a string
  assert self.values[index].kind == ctText
  return self.values[index].textVal


# 指定されたインデックスの引数を Principal として取得する
proc getPrincipal*(self:Request, index:int): Principal =
  ## Get the argument at the specified index as a principal
  assert self.values[index].kind == ctPrincipal
  return self.values[index].principalVal


# 指定されたインデックスの引数を blob として取得する
proc getBlob*(self:Request, index:int): seq[uint8] =
  ## Get the argument at the specified index as a blob (accepts both ctBlob and ctVec of nat8)
  case self.values[index].kind:
  of ctBlob:
    return self.values[index].blobVal
  of ctVec:
    # vec nat8として受信された場合は、各要素からbyte列を構築
    var result = newSeq[uint8](self.values[index].vecVal.len)
    for i, val in self.values[index].vecVal:
      assert val.kind == ctNat8, "Vector elements must be nat8 for blob conversion"
      result[i] = uint8(val.natVal)
    return result
  else:
    assert false, "Expected blob or vec nat8, got: " & $self.values[index].kind


# 指定されたインデックスの引数を Option として取得する
proc getOpt*[T](self:Request, index:int, valueGetter: proc(self: Request, index: int): T): Option[T] =
  ## Get the argument at the specified index as an optional value
  assert self.values[index].kind == ctOpt, "Expected optional type, got: " & $self.values[index].kind
  if self.values[index].optVal.isSome():
    # 一時的なRequestオブジェクトを作成して内部値を取得
    let tempRequest = Request(values: @[self.values[index].optVal.get()])
    return some(valueGetter(tempRequest, 0))
  else:
    return none(T)


# 指定されたインデックスの引数を Vector として取得する
proc getVec*(self:Request, index:int): seq[CandidValue] =
  ## Get the argument at the specified index as a vector
  assert self.values[index].kind == ctVec, "Expected vector type, got: " & $self.values[index].kind
  return self.values[index].vecVal


# 指定されたインデックスの引数を Variant として取得する
proc getVariant*(self:Request, index:int): CandidVariant =
  ## Get the argument at the specified index as a variant
  assert self.values[index].kind == ctVariant, "Expected variant type, got: " & $self.values[index].kind
  return self.values[index].variantVal


# 指定されたインデックスの引数を Function として取得する
proc getFunc*(self:Request, index:int): CandidFunc =
  ## Get the argument at the specified index as a function
  assert self.values[index].kind == ctFunc, "Expected func type, got: " & $self.values[index].kind
  return self.values[index].funcVal


proc getService*(self:Request, index:int): Principal =
  ## Get the argument at the specified index as a service
  assert self.values[index].kind == ctService, "Expected service type, got: " & $self.values[index].kind
  return self.values[index].serviceVal


proc getEmpty*(self:Request, index:int) =
  ## Get the argument at the specified index as empty (validation only)
  assert self.values[index].kind == ctEmpty, "Expected empty type, got: " & $self.values[index].kind
  # Empty型は値を持たないため、型チェックのみ実行


# 指定されたインデックスの引数を Record として取得する
# TODO: Phase 3.2で実装予定 - fromCandidValue関数の依存関係を解決後に有効化
# proc getRecord*(self:Request, index:int): CandidRecord =
#   ## Get the argument at the specified index as a record
#   assert self.values[index].kind == ctRecord, "Expected record type, got: " & $self.values[index].kind
#   return fromCandidValue(self.values[index])


# ================================================================================
# Enum型サポート関数
# ================================================================================

proc getEnum*[T: enum](self: Request, index: int, enumType: typedesc[T]): T =
  ## Get the argument at the specified index as an enum value (from Variant)
  if index < 0 or index >= self.values.len:
    raise newException(IndexDefect, "Request index " & $index & " is out of bounds (0.." & $(self.values.len - 1) & ")")
  
  let candidValue = self.values[index]
  if candidValue.kind != ctVariant:
    raise newException(ValueError, 
      "Expected variant type for enum conversion at index " & $index & ", got: " & $candidValue.kind)
  
  try:
    return getEnumValue(candidValue, enumType)
  except ValueError as e:
    raise newException(ValueError, 
      "Failed to convert variant at index " & $index & " to enum type " & $typeof(T) & ": " & e.msg)


# ================================================================================
# テスト用ヘルパー関数
# ================================================================================

proc newMockRequest*(values: seq[CandidValue]): Request =
  ## テスト用のRequestオブジェクトを作成
  Request(values: values)
