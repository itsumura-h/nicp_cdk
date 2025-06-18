discard """
cmd: nim c --skipUserCfg tests/types/test_nat16.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat16.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat16 tests":
  test "serializeCandid with nat16 zero":
    let nat16Value = newCandidValue(0'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with nat16 small value":
    let nat16Value = newCandidValue(42'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with nat16 max value":
    let nat16Value = newCandidValue(65535'u16)  # 2^16 - 1
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode and decode with nat16 zero":
    let nat16Value = newCandidValue(0'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat16 small value":
    let nat16Value = newCandidValue(42'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat16 max value":
    let nat16Value = newCandidValue(65535'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 65535'u

  test "encode and decode with nat16 boundary values":
    let values = [1'u16, 255'u16, 256'u16, 32767'u16, 32768'u16, 65534'u16]
    for val in values:
      let nat16Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat16Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat16
      check decoded.values[0].natVal == uint(val)

  test "multiple nat16 values":
    let nat16Value1 = newCandidValue(100'u16)
    let nat16Value2 = newCandidValue(200'u16)
    let nat16Value3 = newCandidValue(65535'u16)
    let encoded = encodeCandidMessage(@[nat16Value1, nat16Value2, nat16Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 100'u
    check decoded.values[1].kind == ctNat16
    check decoded.values[1].natVal == 200'u
    check decoded.values[2].kind == ctNat16
    check decoded.values[2].natVal == 65535'u

  test "nat16 value properties":
    let nat16Value = newCandidValue(1000'u16)
    check nat16Value.kind == ctNat16
    check nat16Value.natVal == 1000'u 