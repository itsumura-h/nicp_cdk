discard """
cmd: nim c --skipUserCfg tests/types/test_text.nim
"""
# nim c -r --skipUserCfg tests/types/test_text.nim

import unittest
import std/strutils
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_text tests":
  test "encode with empty string":
    let textValue = newCandidText("")
    let encoded = encodeCandidMessage(@[textValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 長さ(1バイト) + 文字列(0バイト) = 8バイト
    check encoded.len == 8
    # 長さフィールドが0であることを確認
    check encoded[7] == 0'u8


  test "encode with simple string":
    let textValue = newCandidText("hello")
    let encoded = encodeCandidMessage(@[textValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 長さ(1バイト) + 文字列(5バイト) = 13バイト
    check encoded.len == 13
    # 長さフィールドが5であることを確認
    check encoded[7] == 5'u8
    # 文字列の内容を確認
    check encoded[8..12] == @[byte('h'), byte('e'), byte('l'), byte('l'), byte('o')]


  test "encode with Japanese string":
    let textValue = newCandidText("こんにちは")
    let encoded = encodeCandidMessage(@[textValue])
    # 日本語は1文字3バイトのUTF-8なので、「こんにちは」は15バイト
    let expectedLen = 4 + 3 + 1 + 15  # ヘッダー + 型テーブル + 長さ + 文字列
    check encoded.len == expectedLen
    # 長さフィールドが15であることを確認
    check encoded[7] == 15'u8


  test "encode and decode with simple string":
    let textValue = newCandidText("world")
    let encoded = encodeCandidMessage(@[textValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == "world"


  test "encode and decode with empty string":
    let textValue = newCandidText("")
    let encoded = encodeCandidMessage(@[textValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == ""


  test "encode and decode with Japanese string":
    let textValue = newCandidText("日本語テスト")
    let encoded = encodeCandidMessage(@[textValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == "日本語テスト"


  test "encode and decode with special characters":
    let textValue = newCandidText("Hello\nWorld\t!")
    let encoded = encodeCandidMessage(@[textValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == "Hello\nWorld\t!"


  test "multiple text values":
    let textValue1 = newCandidText("first")
    let textValue2 = newCandidText("second")
    let textValue3 = newCandidText("third")
    let encoded = encodeCandidMessage(@[textValue1, textValue2, textValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == "first"
    check decoded.values[1].kind == ctText
    check decoded.values[1].textVal == "second"
    check decoded.values[2].kind == ctText
    check decoded.values[2].textVal == "third"


  test "text value type check":
    let textValue = newCandidText("test")
    check textValue.kind == ctText
    check textValue.textVal == "test"


  test "newCandidValue with string":
    let textValue = newCandidValue("test string")
    check textValue.kind == ctText
    check textValue.textVal == "test string"


  test "long string":
    let longString = "a".repeat(1000)
    let textValue = newCandidText(longString)
    let encoded = encodeCandidMessage(@[textValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == longString
    check decoded.values[0].textVal.len == 1000 