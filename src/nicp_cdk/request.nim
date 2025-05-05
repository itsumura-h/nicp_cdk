import ./ic_types/candid
import ./ic_types/ic_principal
import ./ic0/ic0


type Request* = object
  values: seq[CandidValue]

proc new*(_:type Request): Request =
  let n = ic0_msg_arg_data_size()
  var data = newSeq[byte](n)
  ic0_msg_arg_data_copy(ptrToInt(addr data[0]), 0, n)
  let values = parseCandidArgs(data)
  return Request(values: values)

# 指定されたインデックスの引数を bool として取得する
proc getBool*(self:Request, index:int): bool =
  ## Get the argument at the specified index as a bool
  assert self.values[index].kind == ctBool
  return self.values[index].boolVal

proc getNat*(self:Request, index:int): Natural =
  ## Get the argument at the specified index as a nat
  assert self.values[index].kind == ctNat
  return self.values[index].natVal

# 指定されたインデックスの引数を int32 として取得する
proc getInt32*(self:Request, index:int): int32 =
  ## Get the argument at the specified index as an int32
  assert self.values[index].kind == ctInt32
  return self.values[index].intVal.int32

# 指定されたインデックスの引数を int として取得する
proc getInt*(self:Request, index:int): int =
  ## Get the argument at the specified index as an int
  assert self.values[index].kind == ctInt
  return self.values[index].intVal

# 指定されたインデックスの引数を float32 として取得する
proc getFloat*(self:Request, index:int): float32 =
  ## Get the argument at the specified index as a float32
  assert self.values[index].kind == ctFloat32
  return self.values[index].float32Val

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
