discard """
cmd: nim c --skipUserCfg tests/types/test_int32.nim
"""
# nim c -r --skipUserCfg tests/types/test_int32.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int32 tests":
  test "serializeCandid with int32 zero":
    let int32Value = newCandidValue(0'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with int32 positive value":
    let int32Value = newCandidValue(42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with int32 negative value":
    let int32Value = newCandidValue(-42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with int32 max value":
    let int32Value = newCandidValue(2147483647'i32)  # 2^31 - 1
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "serializeCandid with int32 min value":
    let int32Value = newCandidValue(-2147483648'i32)  # -2^31
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode and decode with int32 zero":
    let int32Value = newCandidValue(0'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == 0

  test "encode and decode with int32 positive value":
    let int32Value = newCandidValue(42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == 42

  test "encode and decode with int32 negative value":
    let int32Value = newCandidValue(-42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == -42

  test "encode and decode with int32 max value":
    let int32Value = newCandidValue(2147483647'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == 2147483647

  test "encode and decode with int32 min value":
    let int32Value = newCandidValue(-2147483648'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == -2147483648

  test "encode and decode with int32 boundary values":
    let values = [1'i32, -1'i32, 65535'i32, -65535'i32, 2147483646'i32, -2147483647'i32]
    for val in values:
      let int32Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int32Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt32
      check decoded.values[0].intVal == int(val)

  test "multiple int32 values":
    let int32Value1 = newCandidValue(1000'i32)
    let int32Value2 = newCandidValue(-2000'i32)
    let int32Value3 = newCandidValue(2147483647'i32)
    let encoded = encodeCandidMessage(@[int32Value1, int32Value2, int32Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].intVal == 1000
    check decoded.values[1].kind == ctInt32
    check decoded.values[1].intVal == -2000
    check decoded.values[2].kind == ctInt32
    check decoded.values[2].intVal == 2147483647

  test "int32 value properties":
    let int32Value = newCandidValue(-100000'i32)
    check int32Value.kind == ctInt32
    check int32Value.intVal == -100000 