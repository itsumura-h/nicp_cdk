discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_bool.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_bool tests":
  test "encode with true":
    let boolValue = newCandidBool(true)
    let encoded = encodeCandidMessage(@[boolValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト
    check encoded.len == 8
    # 最後のバイトがtrueを表す1であることを確認
    check encoded[^1] == 1'u8


  test "encode with false":
    let boolValue = newCandidBool(false)
    let encoded = encodeCandidMessage(@[boolValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト
    check encoded.len == 8
    # 最後のバイトがfalseを表す0であることを確認
    check encoded[^1] == 0'u8 


  test "encode and decode with true":
    let boolValue = newCandidBool(true)
    let encoded = encodeCandidMessage(@[boolValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctBool
    check decoded.values[0].boolVal == true


  test "encode and decode with false":
    let boolValue = newCandidBool(false)
    let encoded = encodeCandidMessage(@[boolValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctBool
    check decoded.values[0].boolVal == false


  test "multiple bool values":
    let boolValue1 = newCandidBool(true)
    let boolValue2 = newCandidBool(false)
    let boolValue3 = newCandidBool(true)
    let encoded = encodeCandidMessage(@[boolValue1, boolValue2, boolValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctBool
    check decoded.values[0].boolVal == true
    check decoded.values[1].kind == ctBool
    check decoded.values[1].boolVal == false
    check decoded.values[2].kind == ctBool
    check decoded.values[2].boolVal == true


  test "bool value type check":
    let trueValue = newCandidBool(true)
    let falseValue = newCandidBool(false)
    check trueValue.kind == ctBool
    check falseValue.kind == ctBool
    check trueValue.boolVal == true
    check falseValue.boolVal == false 