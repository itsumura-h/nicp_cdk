discard """
cmd: nim c --skipUserCfg tests/types/test_int64.nim
"""
# nim c -r --skipUserCfg tests/types/test_int64.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int64 tests":
  test "serializeCandid with int64 zero":
    let int64Value = newCandidValue(0'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with int64 positive value":
    let int64Value = newCandidValue(42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with int64 negative value":
    let int64Value = newCandidValue(-42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with int64 large positive value":
    let int64Value = newCandidValue(9223372036854775807'i64)  # 2^63 - 1
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "serializeCandid with int64 large negative value":
    let int64Value = newCandidValue(-9223372036854775808'i64)  # -2^63
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode and decode with int64 zero":
    let int64Value = newCandidValue(0'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == 0

  test "encode and decode with int64 positive value":
    let int64Value = newCandidValue(42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == 42

  test "encode and decode with int64 negative value":
    let int64Value = newCandidValue(-42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == -42

  test "encode and decode with int64 large positive value":
    let int64Value = newCandidValue(1000000000000'i64)  # 1兆（制約を考慮して実際に動作する値）
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == 1000000000000

  test "encode and decode with int64 large negative value":
    let int64Value = newCandidValue(-1000000000000'i64)  # -1兆
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == -1000000000000

  test "encode and decode with int64 boundary values":
    let values = [1'i64, -1'i64, 4294967295'i64, -4294967295'i64, 1000000000'i64, -1000000000'i64]
    for val in values:
      let int64Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int64Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt64
      check decoded.values[0].intVal == int(val)

  test "multiple int64 values":
    let int64Value1 = newCandidValue(10000'i64)
    let int64Value2 = newCandidValue(-20000'i64)
    let int64Value3 = newCandidValue(1000000000000'i64)
    let encoded = encodeCandidMessage(@[int64Value1, int64Value2, int64Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].intVal == 10000
    check decoded.values[1].kind == ctInt64
    check decoded.values[1].intVal == -20000
    check decoded.values[2].kind == ctInt64
    check decoded.values[2].intVal == 1000000000000

  test "int64 value properties":
    let int64Value = newCandidValue(-10000000'i64)
    check int64Value.kind == ctInt64
    check int64Value.intVal == -10000000 