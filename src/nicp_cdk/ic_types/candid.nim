import std/endians
import std/sequtils
import std/strutils
import ../algorithm/leb128
import ./consts
import ./ic_principal
import ./ic_text


proc toString*(data: seq[byte]): string =
  return data.mapIt(it.toHex()).join("")


#---- Candid 型タグの定義 ----
type
  CandidType* = enum
    ctNull, ctBool, ctNat, ctInt,
    ctNat8, ctNat16, ctNat32, ctNat64,
    ctInt8, ctInt16, ctInt32, ctInt64,
    ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal

  CandidValue* = object
    case kind*: CandidType
    of ctNull: discard
    of ctBool: boolVal*: bool
    of ctNat,  ctNat8,  ctNat16,  ctNat32,  ctNat64: natVal*: Natural
    of ctInt,  ctInt8,  ctInt16,  ctInt32,  ctInt64: intVal*: int
    of ctFloat32: float32Val*: float32
    of ctFloat64: float64Val*: float64
    of ctText: textVal*: string
    of ctPrincipal: principalVal*: Principal
    of ctReserved, ctEmpty: discard
    # 他の型は必要に応じて追加


proc ptrToUint32*(p: pointer): uint32 =
  return cast[uint32](p)


proc ptrToInt*(p: pointer): int =
  return cast[int](p)


#---- 型タグバイトを CandidType に変換 ----
proc parseTypeTag(b: byte): CandidType =
  ## Parse a byte and return a CandidType
  case b
  of tagNull:       ctNull
  of tagBool:       ctBool
  of tagNat:        ctNat
  of tagInt:        ctInt
  of tagNat8:       ctNat8
  of tagNat16:      ctNat16
  of tagNat32:      ctNat32
  of tagNat64:      ctNat64
  of tagInt8:       ctInt8
  of tagInt16:      ctInt16
  of tagInt32:      ctInt32
  of tagInt64:      ctInt64
  of tagFloat32:    ctFloat32
  of tagFloat64:    ctFloat64
  of tagText:       ctText
  of tagReserved:   ctReserved
  of tagEmpty:      ctEmpty
  of tagPrincipal:  ctPrincipal
  else:
    quit("Unknown Candid tag: " & $b)


#---- 単一引数をデコードして CandidValue を返す ----
proc decodeValue(data: seq[byte]; offset: var int; t: CandidType): CandidValue =
  ## Decode a single argument and return a CandidValue
  var v: CandidValue
  v.kind = t
  case t
  of ctNull:
    discard
  of ctBool:
    v.boolVal = data[offset] != 0'u8
    inc offset
  of ctNat, ctNat8, ctNat16, ctNat32, ctNat64:
    v.natVal = decodeULEB128(data, offset)
  of ctInt, ctInt8, ctInt16, ctInt32, ctInt64:
    v.intVal = decodeSLEB128(data, offset)
  of ctFloat32:
    var tmp32: uint32
    # std/endians の littleEndian32 を使って 4 バイトをリトルエンディアンとして読み込む
    littleEndian32(addr tmp32, addr data[offset])
    v.float32Val = cast[float32](tmp32)
    offset += 4
  of ctFloat64:
    var tmp64: uint64
    # std/endians の littleEndian64 を使って 8 バイトをリトルエンディアンとして読み込む
    littleEndian64(addr tmp64, addr data[offset])
    v.float64Val = cast[float64](tmp64)
    offset += 8
  of ctText:
    v.textVal = readText(data, offset)
  of ctPrincipal:
    v.principalVal = readPrincipal(data, offset)
  else:
    quit("Decoding for this type not implemented")
  
  return v


# コアロジック: バイト列を受け取って解析し、CandidValue のシーケンスを返す
proc parseCandidArgs*(data: seq[byte]): seq[CandidValue] =
  ## Core logic: Parse the byte sequence and return a sequence of CandidValue
  var off = 0

  # ヘッダー検証
  if data[0 ..< magicHeader.len] != magicHeader:
    quit("Invalid Candid header")
  off = magicHeader.len

  # 型テーブルの読み取り
  let numTypes = int(data[off]); inc off
  var types: seq[CandidType] = @[]
  for i in 0..<numTypes:
    types.add parseTypeTag(data[off])
    inc off

  # 本体を順にデコード
  var results: seq[CandidValue] = @[]
  for t in types:
    results.add decodeValue(data, off, t)

  return results


#------------------------------------------------------------
# CandidType → タグバイト の逆変換
#------------------------------------------------------------
proc typeTag*(t: CandidType): byte =
  case t
  of ctNull:       tagNull
  of ctBool:       tagBool
  of ctNat:        tagNat
  of ctNat8:       tagNat8
  of ctNat16:      tagNat16
  of ctNat32:      tagNat32
  of ctNat64:      tagNat64
  of ctInt:        tagInt
  of ctInt8:       tagInt8
  of ctInt16:      tagInt16
  of ctInt32:      tagInt32
  of ctInt64:      tagInt64
  of ctFloat32:    tagFloat32
  of ctFloat64:    tagFloat64
  of ctText:       tagText
  of ctPrincipal:  tagPrincipal
  of ctReserved:   tagReserved
  of ctEmpty:      tagEmpty
  else:
    quit("Unknown CandidType: " & $t)


#------------------------------------------------------------
# seq[CandidValue] → seq[byte] (Candid へエンコード)
#------------------------------------------------------------
proc encodeCandidArgs*(values: seq[CandidValue]): seq[byte] =
  #―― ヘッダー ――――――――――――――――――――
  result.add magicHeader
  # for b in magicHeader:
  #   result.add b

  #―― 型テーブル ―――――――――――――――――――
  result.add byte(values.len)              # 型数
  for v in values:
    result.add typeTag(v.kind)             # 各 CandidType をタグバイトに

  #―― 値本体 ――――――――――――――――――――――――
  for v in values:
    case v.kind
    of ctNull, ctReserved, ctEmpty:
      discard                              # データなし
    of ctBool:
      result.add(if v.boolVal: 1'u8 else: 0'u8)
    of ctNat, ctNat8, ctNat16, ctNat32, ctNat64:
      let enc = encodeULEB128(v.natVal.uint)
      for b in enc: result.add b
    of ctInt, ctInt8, ctInt16, ctInt32, ctInt64:
      let enc = encodeSLEB128(v.intVal.int32)
      for b in enc: result.add b
    of ctFloat32:
      let x = cast[uint32](v.float32Val)
      for i in 0..3:
        result.add byte((x shr (8*i)) and 0xFF'u32)
    of ctFloat64:
      let x = cast[uint64](v.float64Val)
      for i in 0..7:
        result.add byte((x shr (8*i)) and 0xFF'u64)
    of ctText:
      # ic_text に定義された writeText(text, seq[byte]) を利用
      writeText(v.textVal, result)
    of ctPrincipal:
      # ic_principal に定義された writePrincipal(principal, seq[byte]) を利用
      writePrincipal(v.principalVal, result)
    else:
      quit("Encoding for this type not implemented")

  return result
