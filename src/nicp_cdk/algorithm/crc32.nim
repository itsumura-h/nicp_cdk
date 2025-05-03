type TCrc32* = uint32

const InitCrc32* = TCrc32(uint32.high)  # 0xFFFFFFFF 初期値            :contentReference[oaicite:5]{index=5}

# テーブル生成（Sarwate アルゴリズム準拠）
proc createCrcTable(): array[0..255, TCrc32] =
  for i in 0..255:
    var rem = TCrc32(i)
    for j in 0..7:
      if (rem and 1'u32) > 0:
        rem = (rem shr 1) xor TCrc32(0xedb88320)   # CRC-32 多項式定数  :contentReference[oaicite:6]{index=6}
      else:
        rem = rem shr 1
    result[i] = rem
const crc32table = createCrcTable()  # コンパイル時にテーブル作成 :contentReference[oaicite:7]{index=7}

# バイト単位で CRC-32 更新
proc updateCrc32*(b: byte, crc: var TCrc32) =
  crc = (crc shr 8) xor crc32table[(crc and 0xff'u32) xor uint32(b)]

# seq[byte] 全体の CRC-32 を計算
proc crc32Bytes*(data: seq[byte]): uint32 =
  var crc = InitCrc32
  for b in data:
    updateCrc32(b, crc)
  result = not crc  # 最終的にビット反転                 :contentReference[oaicite:8]{index=8}
