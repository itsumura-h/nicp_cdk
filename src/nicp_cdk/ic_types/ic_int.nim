import ./consts
import ../algorithm/leb128

proc serializeCandid*(value: int32): seq[byte] =
  ## --- int32 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(1); buf.add tagInt32
  buf.add encodeSLEB128(value)
  buf

# proc serializeCandid(value: int64): seq[byte] =
#   ## --- int64 用 serializeCandid ---
#   var buf = newSeq[byte]()
#   buf.add magicHeader
#   buf.add byte(0); buf.add byte(1); buf.add tagInt64
#   # 整数は signed LEB128 が望ましいが、簡易的に unsigned で同様に
#   buf.add encodeSLEB128(value.int)
#   buf

proc serializeCandid*(value: int): seq[byte] =
  ## --- int 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(1); buf.add tagInt
  buf.add encodeSLEB128(int32(value))
  buf

proc serializeCandid*(value: Natural): seq[byte] =
  ## --- Natural 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(1); buf.add tagNat
  buf.add encodeULEB128(uint(value))
  buf
