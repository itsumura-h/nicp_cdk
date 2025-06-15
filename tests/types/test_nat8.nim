discard """
cmd: nim c --skipUserCfg tests/types/test_nat8.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat8.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat8 tests":
  test "serializeCandid with small nat8":
    let nat8Value = newCandidValue(42u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト
    check encoded.len == 8


  test "serializeCandid with zero":
    let nat8Value = newCandidValue(0u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    check encoded.len == 8


  test "serializeCandid with max nat8":
    let nat8Value = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    check encoded.len == 8


  test "encode and decode with small nat8":
    let nat8Value = newCandidValue(123u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 123u


  test "encode and decode with zero":
    let nat8Value = newCandidValue(0u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 0u


  test "encode and decode with max nat8":
    let nat8Value = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 255u


  test "multiple nat8 values":
    let nat8Value1 = newCandidValue(10u8)
    let nat8Value2 = newCandidValue(20u8)
    let nat8Value3 = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value1, nat8Value2, nat8Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 10u
    check decoded.values[1].kind == ctNat8
    check decoded.values[1].natVal == 20u
    check decoded.values[2].kind == ctNat8
    check decoded.values[2].natVal == 255u


  test "nat8 boundary values":
    # Test boundary values: 0, 1, 254, 255
    let values = [0u8, 1u8, 254u8, 255u8]
    for val in values:
      let nat8Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat8Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat8
      check decoded.values[0].natVal == uint(val)


  test "nat8 value type check":
    let nat8Value = newCandidValue(199u8)
    check nat8Value.kind == ctNat8
    check nat8Value.natVal == 199u 