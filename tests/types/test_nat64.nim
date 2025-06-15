discard """
cmd: nim c --skipUserCfg tests/types/test_nat64.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat64.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat64 tests":
  test "serializeCandid with nat64 zero":
    let nat64Value = newCandidValue(0'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with nat64 small value":
    let nat64Value = newCandidValue(42'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with nat64 max value":
    let nat64Value = newCandidValue(18446744073709551615'u64)  # 2^64 - 1
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode and decode with nat64 zero":
    let nat64Value = newCandidValue(0'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat64 small value":
    let nat64Value = newCandidValue(42'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat64 max value":
    let nat64Value = newCandidValue(18446744073709551615'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 18446744073709551615'u

  test "encode and decode with nat64 boundary values":
    let values = [1'u64, 255'u64, 256'u64, 65535'u64, 65536'u64, 4294967295'u64, 4294967296'u64, 18446744073709551614'u64]
    for val in values:
      let nat64Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat64Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat64
      check decoded.values[0].natVal == uint(val)

  test "multiple nat64 values":
    let nat64Value1 = newCandidValue(1000'u64)
    let nat64Value2 = newCandidValue(2000'u64)
    let nat64Value3 = newCandidValue(18446744073709551615'u64)
    let encoded = encodeCandidMessage(@[nat64Value1, nat64Value2, nat64Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 1000'u
    check decoded.values[1].kind == ctNat64
    check decoded.values[1].natVal == 2000'u
    check decoded.values[2].kind == ctNat64
    check decoded.values[2].natVal == 18446744073709551615'u

  test "nat64 value properties":
    let nat64Value = newCandidValue(10000000000'u64)
    check nat64Value.kind == ctNat64
    check nat64Value.natVal == 10000000000'u 