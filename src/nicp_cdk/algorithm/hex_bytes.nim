import std/strutils


proc hexCharVal(c: char): int =
  ## hex 文字を 0..15 の値に変換
  case c
  of '0'..'9': return ord(c) - ord('0')
  of 'a'..'f': return ord(c) - ord('a') + 10
  of 'A'..'F': return ord(c) - ord('A') + 10
  else: raise newException(ValueError, "Invalid hex character: " & $c)


proc hexToBytes*(hexStr: string): seq[uint8] =
  ## 16進文字列 (`"deadbeef"` など) をバイト列に変換する
  var s = hexStr.strip()
  # allow optional 0x or 0X prefix
  if s.len >= 2 and s[0] == '0' and (s[1] == 'x' or s[1] == 'X'):
    s = s[2..^1]

  if s.len mod 2 == 1:
    raise newException(ValueError, "hex string must have even length")

  result = newSeq[uint8](s.len div 2)
  var idx = 0
  while idx < s.len:
    let hi = hexCharVal(s[idx])
    let lo = hexCharVal(s[idx+1])
    result[idx div 2] = uint8((hi shl 4) or lo)
    idx += 2


# バイト列を16進数文字列に変換するヘルパー関数
proc toHexString*(bytes: seq[uint8]): string =
  result = ""
  for b in bytes:
    result.add(b.toHex(2))


## hexToBytes2 removed; use hexToBytes1 which supports optional 0x/0X prefix
