import std/sequtils
import std/strutils
import base32 # https://github.com/OpenSystemsLab/base32.nim :contentReference[oaicite:9]{index=9}
import ../algorithm/crc32
import ../algorithm/leb128
import ../ic0/ic0


# https://wiki.internetcomputer.org/wiki/Principal
const
  MANAGEMENT_CANISTER = "aaaaa-aa"
  GOVERNANCE_CANISTER = "rrkah-fqaaa-aaaaa-aaaaq-cai"
  LEDGER_CANISTER = "ryjl3-tyaaa-aaaaa-aaaba-cai"
  NETWORK_NERVOUS_SYSTEM_CANISTER = "tdb26-jop6k-aogll-7ltgs-eruif-6kk7m-qpktf-gdiqx-mxtrf-vb5e6-eqe"
  ANONYMOUS_USER = "2vxsx-fae"


type Principal* = object
  bytes*: seq[byte]
  text*: string

proc `$`*(self: Principal): string =
  return self.text


# バイナリ → ハイフン区切りの Base32 文字列に変換
proc fromBlob*(_:type Principal, raw: seq[byte]): Principal =
  ## https://internetcomputer.org/docs/motoko/main/base/Principal#function-fromblob
  # (1) CRC-32 を計算し、4 バイトのビッグエンディアンで先頭に付加
  let checksum = crc32Bytes(raw)
  var payload = newSeq[byte](4 + raw.len)
  payload[0] = byte(checksum shr 24)
  payload[1] = byte(checksum shr 16)
  payload[2] = byte(checksum shr 8)
  payload[3] = byte(checksum and 0xFF'u32)
  payload[4..^1] = raw
  
  # (2) seq[byte] → seq[char] に変換してから Base32 符号化
  let charSeq = payload.mapIt(char(it))   # mapIt により byte→char へ  :contentReference[oaicite:10]{index=10}
  let b32 = base32.encode(charSeq).replace("=", "")               # encode の引数は seq[char]     :contentReference[oaicite:11]{index=11}
  let smallB32 = b32.mapIt(it.toLowerAscii())

  # (3) 5 文字ごとにハイフンを挿入
  var text = ""
  for i in 0..<smallB32.len:
    text.add smallB32[i]
    if i > 0 and i mod 5 == 4:
      text.add '-'

  return Principal(
    text: text,
    bytes: raw
  )


proc fromText*(_:type Principal, text: string): Principal =
  ## https://internetcomputer.org/docs/motoko/main/base/Principal#function-fromtext
  # (1) ハイフンを除去して小文字に統一
  let cleanText = text.replace("-", "").toLowerAscii()
  
  # (2) Base32 デコード
  let decoded = base32.decode(cleanText)
  
  # (3) seq[char] → seq[byte] に変換
  let bytes = decoded.mapIt(byte(it))
  
  # (4) 先頭4バイトのCRC-32を検証
  let checksum = (uint32(bytes[0]) shl 24) or
                 (uint32(bytes[1]) shl 16) or
                 (uint32(bytes[2]) shl 8) or
                 uint32(bytes[3])
  
  # 残りのバイト列を取得
  result.bytes = bytes[4..^1]
  
  # CRC-32を検証
  let calculatedChecksum = crc32Bytes(result.bytes)
  assert checksum == calculatedChecksum, "Invalid Principal checksum"
  
  result.text = text


proc managementCanister*(_:type Principal): Principal =
  return Principal.fromText(MANAGEMENT_CANISTER)
  

proc governanceCanister*(_:type Principal): Principal =
  return Principal.fromText(GOVERNANCE_CANISTER)
  

proc ledgerCanister*(_:type Principal): Principal =
  return Principal.fromText(LEDGER_CANISTER)
  

proc networkNervousSystemCanister*(_:type Principal): Principal =
  return Principal.fromText(NETWORK_NERVOUS_SYSTEM_CANISTER)
  

proc anonymousUser*(_:type Principal): Principal =
  return Principal.fromText(ANONYMOUS_USER)


proc readPrincipal*(data: seq[byte]; offset: var int): Principal =
  ## Read a principal from a byte sequence and return it
  # 長さを読み取る
  let len = int(decodeULEB128(data, offset))
  let principalLength = data[offset ..< offset+len][len-1].int
  offset += len
  # 長さ分のバイト列を取得
  let principalBytes = data[offset ..< offset + principalLength]
  offset += principalLength
  let principal = Principal.fromBlob(principalBytes)
  return principal

proc selfPrincipal*(): Principal =
  ## Get the principal of the current canister
  let n = ic0_canister_self_size()
  var data = newSeq[byte](n)
  ic0_canister_self_copy(cast[int](addr data[0]), 0, n)
  return Principal.fromBlob(data)
