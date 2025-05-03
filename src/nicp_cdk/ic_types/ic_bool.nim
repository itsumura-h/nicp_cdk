import ./consts

proc serializeCandid*(value: bool): seq[byte] =
  ## --- bool 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(1); buf.add tagBool
  buf.add if value: 1'u8 else: 0'u8
  buf
