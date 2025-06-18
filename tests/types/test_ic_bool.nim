discard """
cmd: nim c --skipUserCfg tests/types/test_ic_bool.nim
"""
# nim c -r --skipUserCfg tests/types/test_ic_bool.nim

import unittest
import ../../src/nicp_cdk/ic_types/ic_bool
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_bool tests":
  test "serializeCandid with true":
    let result = serializeCandid(true)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 値(1バイト)
    check result.len == 7
    # 最後のバイトがtrueを表す1であることを確認
    check result[^1] == 1'u8


  test "serializeCandid with false":
    let result = serializeCandid(false)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 値(1バイト)
    check result.len == 7
    # 最後のバイトがfalseを表す0であることを確認
    check result[^1] == 0'u8 


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
