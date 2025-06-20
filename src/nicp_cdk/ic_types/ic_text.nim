import std/sequtils
import std/strutils
import ./consts
import ../algorithm/leb128


proc readText*(data: seq[byte]; offset: var int): string =
  ## Read a string from a byte sequence and return it
  let len = int(decodeULEB128(data, offset))
  let slice = data[offset ..< offset + len]
  offset += len
  return slice.map(proc(u: byte): char = char(u)).join()


proc serializeCandid*(value: string): seq[byte] =
  ## --- string 用 serializeCandid ---
  var buf = newSeq[byte]()
  # DIDL0 header
  buf.add magicHeader
  # 型テーブル: 値数=1, 型タグ=text
  buf.add byte(1); buf.add tagText
  # 本文: 文字列長 (ULEB128) + UTF-8 バイト列
  let utf8Bytes = value.cstring
  buf.add encodeULEB128(uint(utf8Bytes.len))
  for b in utf8Bytes: buf.add byte(b)
  buf


proc toBlob*(value: string): seq[byte] =
  ## --- string 用 toBlob ---
  return value.map(proc(c:char): byte = byte(c)).toSeq()
