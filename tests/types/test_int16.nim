discard """
cmd: nim c --skipUserCfg tests/types/test_int16.nim
"""
# nim c -r --skipUserCfg tests/types/test_int16.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int16 tests":
  test "serializeCandid with int16 zero":
    let int16Value = newCandidValue(0'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with int16 positive value":
    let int16Value = newCandidValue(42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with int16 negative value":
    let int16Value = newCandidValue(-42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with int16 max value":
    let int16Value = newCandidValue(32767'i16)  # 2^15 - 1
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "serializeCandid with int16 min value":
    let int16Value = newCandidValue(-32768'i16)  # -2^15
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode and decode with int16 zero":
    let int16Value = newCandidValue(0'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == 0

  test "encode and decode with int16 positive value":
    let int16Value = newCandidValue(42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == 42

  test "encode and decode with int16 negative value":
    let int16Value = newCandidValue(-42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == -42

  test "encode and decode with int16 max value":
    let int16Value = newCandidValue(32767'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == 32767

  test "encode and decode with int16 min value":
    let int16Value = newCandidValue(-32768'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == -32768

  test "encode and decode with int16 boundary values":
    let values = [1'i16, -1'i16, 255'i16, -255'i16, 32766'i16, -32767'i16]
    for val in values:
      let int16Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int16Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt16
      check decoded.values[0].intVal == int(val)

  test "multiple int16 values":
    let int16Value1 = newCandidValue(100'i16)
    let int16Value2 = newCandidValue(-200'i16)
    let int16Value3 = newCandidValue(32767'i16)
    let encoded = encodeCandidMessage(@[int16Value1, int16Value2, int16Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].intVal == 100
    check decoded.values[1].kind == ctInt16
    check decoded.values[1].intVal == -200
    check decoded.values[2].kind == ctInt16
    check decoded.values[2].intVal == 32767

  test "int16 value properties":
    let int16Value = newCandidValue(-1000'i16)
    check int16Value.kind == ctInt16
    check int16Value.intVal == -1000 