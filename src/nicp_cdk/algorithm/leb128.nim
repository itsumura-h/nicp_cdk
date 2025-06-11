#---- ULEB128 デコード ----
proc decodeULEB128*(data: seq[byte]; offset: var int): uint =
  ## Decode an unsigned LEB128 encoded integer
  var shift = 0
  while true:
    let b = data[offset]
    inc offset
    result = result or (uint(b and 0x7Fu) shl shift)
    if (b and 0x80u) == 0u: break
    shift += 7
  return result

#---- SLEB128 デコード ----
proc decodeSLEB128*(data: seq[byte]; offset: var int): int =
  ## Decode a signed LEB128 encoded integer
  var shift = 0
  var byteVal: byte = 0'u8
  while true:
    byteVal = data[offset]
    inc offset
    result = result or (int(byteVal and 0x7Fu) shl shift)
    shift += 7
    if (byteVal and 0x80u) == 0'u8: break
  # 最後に読み取ったバイトの符号ビット(0x40)で符号拡張
  if (byteVal and 0x40u) != 0'u8 and shift < (sizeof(int) * 8):
    result = result or ( -1 shl shift )
  return result


# --- LEB128 エンコード (Unsigned) ---
proc encodeULEB128*(n: uint): seq[byte] =
  ## Encode an unsigned integer into LEB128 format
  var x = n
  var buf = newSeq[byte]()
  while true:
    let byteVal = byte(x and 0x7Fu)
    x = x shr 7
    if x != 0:
      buf.add byteVal or byte(0x80)
    else:
      buf.add byteVal
      break
  buf


# --- LEB128 エンコード (Signed) ---
proc encodeSLEB128*(n: int32): seq[byte] =
  ## Encode a signed integer into LEB128 format
  var value = n
  var buf = newSeq[byte]()
  while true:
    # 下位7ビットを抽出
    let byteVal = uint8(value and 0x7F)
    # 右シフト(算術シフト)で次のチャンクへ
    value = value shr 7
    # 最終バイト判定: 残り値が 0 (正) or -1 (負) かつ符号ビットと一致
    let signBit = (byteVal and 0x40'u8) != 0'u8
    let isLast  = (value == 0 and not signBit) or (value == -1 and signBit)
    if isLast:
      # 継続ビットなし
      buf.add byteVal
      break
    else:
      # 次バイトありフラグをセット
      buf.add byteVal or 0x80'u8
  buf
