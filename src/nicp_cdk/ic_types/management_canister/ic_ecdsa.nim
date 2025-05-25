import ../../algorithm/leb128
import ../consts


# 1) Variant のエンコード (index + payload)
proc encodeCandidVariant*(index: uint, payload: seq[byte]): seq[byte] =
  result = encodeULEB128(index)
  for b in payload:
    result.add b


# 3) Vec のエンコード
proc encodeCandidVec*[T](items: seq[T], encodeElem: proc(x: T): seq[byte]): seq[byte] =
  result = encodeULEB128(uint(items.len))
  for it in items:
    for b in encodeElem(it):
      result.add b


# 2) Optional のエンコード
proc encodeCandidOptional*(blob: seq[byte]): seq[byte] =
  result = @[]
  if blob.len > 0:
    result.add 0x01'u8                     # Some タグ
    # blob を vec nat8 としてエンコード
    for b in encodeCandidVec(blob, proc(b: byte): seq[byte] = @[b]):
      result.add b
  else:
    result.add 0x00'u8                     # None タグ


# 4) Record の «値» のエンコード: フィールドのバイト列を順に連結
proc encodeCandidRecord*(fields: seq[seq[byte]]): seq[byte] =
  result = @[]
  for f in fields:
    for b in f:
      result.add b


# EcdsaPublicKeyArgs 型定義
type
  EcdsaKeyCurve* = enum
    secp256k1 = 0
    secp256r1 = 1
    ed25519 = 2

  EcdsaKeyName* = enum
    dfxTestKey = "dfx_test_key"
    testKey1 = "test_key_1"
    key1 = "key_1"

  EcdsaPublicKeyArgs* = object
    canisterId*: seq[byte]        # 空シーケンスで None 扱い
    derivationPath*: seq[byte]    # 単一の blob (ユーザ実装例に合わせる)
    keyCurve*: EcdsaKeyCurve
    keyName*: EcdsaKeyName


# テキストのエンコーダ (blob として使う場合)
proc encodeStringBytes*(s: cstring): seq[byte] =
  result = encodeULEB128(uint(s.len))
  for c in s:
    result.add byte(c)


# 5) EcdsaPublicKeyArgs の値部分を全部エンコード
proc serializeCandid*(arg: EcdsaPublicKeyArgs): seq[byte] =
  # 5.1 key_id レコードのフィールドをエンコード
  let nameStr = $arg.keyName
  let nameBytes = encodeStringBytes(nameStr.cstring)
  # variant: secp256k1 -> index 0, 他は ordinal
  let curveIndex = arg.keyCurve.uint
  let curveBytes = encodeCandidVariant(curveIndex, @[])
  let keyIdBytes = encodeCandidRecord(@[nameBytes, curveBytes])

  # 5.2 canister_id (optional blob)
  let canBytes = encodeCandidOptional(arg.canisterId)

  # 5.3 derivation_path (単一 blob として vec nat8)
  let derivBytes = encodeCandidVec(arg.derivationPath, proc(b: byte): seq[byte] = @[b])

  result.add magicHeader
  # 5.4 全フィールドをソート済み順に連結: [key_id, canister_id, derivation_path]
  result.add encodeCandidRecord(@[keyIdBytes, canBytes, derivBytes])
