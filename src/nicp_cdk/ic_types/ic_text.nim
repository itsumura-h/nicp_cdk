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



proc toBlob*(value: string): seq[byte] =
  ## --- string 用 toBlob ---
  return value.map(proc(c:char): byte = byte(c)).toSeq()
