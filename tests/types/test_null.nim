discard """
cmd: nim c --skipUserCfg tests/types/test_null.nim
"""
# nim c -r --skipUserCfg tests/types/test_null.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_null tests":
  test "encode with null":
    let nullValue = newCandidNull()
    let encoded = encodeCandidMessage(@[nullValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) = 7バイト（null値は値を持たない）
    check encoded.len == 7


  test "encode and decode with null":
    let nullValue = newCandidNull()
    let encoded = encodeCandidMessage(@[nullValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNull


  test "null value has no data":
    let nullValue = newCandidNull()
    check nullValue.kind == ctNull
    # null値は値フィールドを持たないことを確認


  test "multiple null values":
    let nullValue1 = newCandidNull()
    let nullValue2 = newCandidNull()
    let encoded = encodeCandidMessage(@[nullValue1, nullValue2])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 2
    check decoded.values[0].kind == ctNull
    check decoded.values[1].kind == ctNull 
