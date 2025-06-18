discard """
cmd: nim c --skipUserCfg tests/types/test_nat32.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat32.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat32 tests":
  test "serializeCandid with nat32 zero":
    let nat32Value = newCandidValue(0'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with nat32 small value":
    let nat32Value = newCandidValue(42'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with nat32 max value":
    let nat32Value = newCandidValue(4294967295'u32)  # 2^32 - 1
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode and decode with nat32 zero":
    let nat32Value = newCandidValue(0'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat32 small value":
    let nat32Value = newCandidValue(42'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat32 max value":
    let nat32Value = newCandidValue(4294967295'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 4294967295'u

  test "encode and decode with nat32 boundary values":
    let values = [1'u32, 255'u32, 256'u32, 65535'u32, 65536'u32, 4294967294'u32]
    for val in values:
      let nat32Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat32Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat32
      check decoded.values[0].natVal == uint(val)

  test "multiple nat32 values":
    let nat32Value1 = newCandidValue(100'u32)
    let nat32Value2 = newCandidValue(200'u32)
    let nat32Value3 = newCandidValue(4294967295'u32)
    let encoded = encodeCandidMessage(@[nat32Value1, nat32Value2, nat32Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 100'u
    check decoded.values[1].kind == ctNat32
    check decoded.values[1].natVal == 200'u
    check decoded.values[2].kind == ctNat32
    check decoded.values[2].natVal == 4294967295'u

  test "nat32 value properties":
    let nat32Value = newCandidValue(1000'u32)
    check nat32Value.kind == ctNat32
    check nat32Value.natVal == 1000'u 