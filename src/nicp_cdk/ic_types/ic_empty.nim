import ./consts

proc serializeCandid*(): seq[byte] =
  ## --- 空の Response 用 serializeCandid ---
  var buf = newSeq[byte]()
  buf.add magicHeader
  buf.add byte(0)
  return buf
