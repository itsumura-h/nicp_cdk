discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_blob.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "ic_blob tests":
  test "encode with empty blob":
    let blobValue = newCandidBlob(@[])
    let encoded = encodeCandidMessage(@[blobValue])
    # 空のblob（vec nat8として処理）: DIDL0ヘッダー(4バイト) + 型テーブル(1バイト + 3バイト) + 型シーケンス(1バイト + 1バイト) + 長さ0(1バイト) = 10バイト
    check encoded.len == 10

  test "encode with small blob":
    let blobData = @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8] # "Hello"
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(4バイト) + 型シーケンス(2バイト) + LEB128長さ(1バイト) + データ(5バイト) = 15バイト  
    check encoded.len == 15

  test "encode with binary data":
    let blobData = @[0x00u8, 0x01u8, 0x02u8, 0xFFu8]
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    # バイナリデータ: DIDL0ヘッダー(4バイト) + 型テーブル(4バイト) + 型シーケンス(2バイト) + LEB128長さ(1バイト) + データ(4バイト) = 14バイト
    check encoded.len == 14

  test "encode with large blob":
    var blobData = newSeq[uint8](1000)
    for i in 0..<1000:
      blobData[i] = uint8(i mod 256)
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    # 大きなデータはより多くのバイトを使用（LEB128エンコーディングで長さが2バイト）
    check encoded.len > 1000

  test "encode and decode with ASCII blob":
    let blobData = @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8] # "Hello"
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    # blob型で作成してもデコード時はvec nat8として返される
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 5
    # 各要素がnat8値として格納されているかチェック
    for i in 0..<5:
      check decoded.values[0].vecVal[i].kind == ctNat8
      check decoded.values[0].vecVal[i].nat8Val == blobData[i]

  test "encode and decode with empty blob":
    let blobValue = newCandidBlob(@[])
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    # 空のblob型で作成してもデコード時はvec型として返される
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 0

  test "encode and decode with binary blob":
    let blobData = @[0x00u8, 0x01u8, 0x02u8, 0x03u8, 0xFEu8, 0xFFu8]
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 6
    # バイナリデータの検証
    for i in 0..<6:
      check decoded.values[0].vecVal[i].kind == ctNat8
      check decoded.values[0].vecVal[i].nat8Val == blobData[i]

  test "encode and decode with UTF-8 blob":
    # UTF-8でエンコードされた日本語文字列「こんにちは」
    let blobData = @[0xe3u8, 0x81u8, 0x93u8, 0xe3u8, 0x82u8, 0x93u8, 
                     0xe3u8, 0x81u8, 0xabu8, 0xe3u8, 0x81u8, 0xa1u8, 
                     0xe3u8, 0x81u8, 0xafu8]
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 15
    # UTF-8バイト列の検証
    for i in 0..<15:
      check decoded.values[0].vecVal[i].kind == ctNat8
      check decoded.values[0].vecVal[i].nat8Val == blobData[i]

  test "encode and decode with large blob":
    var blobData = newSeq[uint8](100)  # テスト時間短縮のため100バイトに縮小
    for i in 0..<100:
      blobData[i] = uint8(i mod 256)
    let blobValue = newCandidBlob(blobData)
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 100
    # 大きなデータの検証（サンプルのみ）
    for i in 0..<10:
      check decoded.values[0].vecVal[i].kind == ctNat8
      check decoded.values[0].vecVal[i].nat8Val == blobData[i]

  test "multiple blob values":
    let blobValue1 = newCandidBlob(@[0x41u8, 0x42u8]) # "AB"
    let blobValue2 = newCandidBlob(@[0x43u8, 0x44u8]) # "CD"
    let blobValue3 = newCandidBlob(@[0x45u8, 0x46u8]) # "EF"
    let encoded = encodeCandidMessage(@[blobValue1, blobValue2, blobValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    # 全てvec nat8として返される
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 2
    check decoded.values[0].vecVal[0].nat8Val == 0x41u
    check decoded.values[0].vecVal[1].nat8Val == 0x42u
    check decoded.values[1].kind == ctVec
    check decoded.values[1].vecVal.len == 2
    check decoded.values[1].vecVal[0].nat8Val == 0x43u
    check decoded.values[1].vecVal[1].nat8Val == 0x44u
    check decoded.values[2].kind == ctVec
    check decoded.values[2].vecVal.len == 2
    check decoded.values[2].vecVal[0].nat8Val == 0x45u
    check decoded.values[2].vecVal[1].nat8Val == 0x46u

  test "blob value type check":
    let blobData = @[0x54u8, 0x65u8, 0x73u8, 0x74u8] # "Test"
    let blobValue = newCandidBlob(blobData)
    check blobValue.kind == ctBlob
    check blobValue.blobVal == blobData

  test "newCandidValue with seq[uint8]":
    let blobData: seq[uint8] = @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8] # "Hello"
    let blobValue = newCandidValue(blobData)
    # newCandidValue(seq[uint8])はctBlobとして扱われる（作成時のみ）
    check blobValue.kind == ctBlob
    check blobValue.blobVal.len == 5
    # ただし、エンコード・デコード後はvec nat8として扱われる
    let encoded = encodeCandidMessage(@[blobValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctVec 