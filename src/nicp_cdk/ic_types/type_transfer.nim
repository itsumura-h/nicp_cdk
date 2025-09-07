import std/strutils


proc toBytes*(data: seq[int]): seq[byte] =
  result = newSeq[byte](data.len)
  for i, d in data:
    result[i] = d.byte


proc toBytes*(data: string): seq[byte] =
  ## 16進数文字列を2文字ずつ区切ってseq[byte]に変換
  ## 例: "4449444c" -> @[0x44, 0x49, 0x44, 0x4c]
  # echo "data.len: ", data.len
  # if data.len mod 2 != 0:
  #   raise newException(ValueError, "16進数文字列の長さは偶数である必要があります")
  
  result = newSeq[byte](data.len div 2)
  for i in 0..<(data.len div 2):
    let hexPair = data[i*2..<i*2+2]
    result[i] = parseHexInt(hexPair).byte


proc toString*(data: seq[byte]): string =
  result = ""
  for b in data:
    result.add(b.toHex())
