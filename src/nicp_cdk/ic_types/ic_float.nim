import ./consts


# IEEE754 の 32bit 浮動小数点をビット列 (uint32) に変換
proc floatToBits(x: float32): uint32 {.inline.} =
  let p = cast[ptr uint32](addr x)
  return p[]

proc serializeCandid*(value: float32): seq[byte] =
  ## --- float32 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(1); buf.add tagFloat32
  # IEEE754 little-endian ビットをそのまま格納
  let bits = cast[uint32](value.floatToBits)
  for shift in 0 ..< 4:
    buf.add byte((bits shr (8*shift)) and 0xFF'u64)
  buf

# proc serializeCandid(value: float64): seq[byte] =
#   ## --- float 用 serializeCandid (64bit) ---
#   var buf = newSeq[byte]()
#   buf.add magicHeader
#   buf.add byte(0); buf.add byte(1); buf.add tagFloat64
#   # IEEE754 little-endian ビットをそのまま格納
#   let bits = cast[uint64](value.floatToBits)
#   for shift in 0 ..< 8:
#     buf.add byte((bits shr (8*shift)) and 0xFF'u64)
#   buf
