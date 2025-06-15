discard """
cmd: nim c --skipUserCfg tests/types/test_int8.nim
"""
# nim c -r --skipUserCfg tests/types/test_int8.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int8 tests":
  test "serializeCandid with int8 zero":
    let int8Value = newCandidValue(0'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "serializeCandid with int8 positive value":
    let int8Value = newCandidValue(42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "serializeCandid with int8 negative value":
    let int8Value = newCandidValue(-42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "serializeCandid with int8 max value":
    let int8Value = newCandidValue(127'i8)  # 2^7 - 1
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "serializeCandid with int8 min value":
    let int8Value = newCandidValue(-128'i8)  # -2^7
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode and decode with int8 zero":
    let int8Value = newCandidValue(0'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == 0

  test "encode and decode with int8 positive value":
    let int8Value = newCandidValue(42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == 42

  test "encode and decode with int8 negative value":
    let int8Value = newCandidValue(-42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == -42

  test "encode and decode with int8 max value":
    let int8Value = newCandidValue(127'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == 127

  test "encode and decode with int8 min value":
    let int8Value = newCandidValue(-128'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == -128

  test "encode and decode with int8 boundary values":
    let values = [1'i8, -1'i8, 126'i8, -127'i8]
    for val in values:
      let int8Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int8Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt8
      check decoded.values[0].intVal == int(val)

  test "multiple int8 values":
    let int8Value1 = newCandidValue(10'i8)
    let int8Value2 = newCandidValue(-20'i8)
    let int8Value3 = newCandidValue(127'i8)
    let encoded = encodeCandidMessage(@[int8Value1, int8Value2, int8Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].intVal == 10
    check decoded.values[1].kind == ctInt8
    check decoded.values[1].intVal == -20
    check decoded.values[2].kind == ctInt8
    check decoded.values[2].intVal == 127

  test "int8 value properties":
    let int8Value = newCandidValue(-50'i8)
    check int8Value.kind == ctInt8
    check int8Value.intVal == -50 