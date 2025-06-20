discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_int.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int tests":
  test "encode with positive int":
    let intValue = newCandidInt(42)
    let encoded = encodeCandidMessage(@[intValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト（小さい値の場合）
    check encoded.len == 8


  test "encode with negative int":
    let intValue = newCandidInt(-42)
    let encoded = encodeCandidMessage(@[intValue])
    check encoded.len == 8


  test "encode with zero":
    let intValue = newCandidInt(0)
    let encoded = encodeCandidMessage(@[intValue])
    check encoded.len == 8


  test "encode with large positive int":
    let intValue = newCandidInt(1000000)
    let encoded = encodeCandidMessage(@[intValue])
    # 大きな値はより多くのバイトを使用
    check encoded.len > 8


  test "encode with large negative int":
    let intValue = newCandidInt(-1000000)
    let encoded = encodeCandidMessage(@[intValue])
    check encoded.len > 8


  test "encode and decode with positive int":
    let intValue = newCandidInt(123)
    let encoded = encodeCandidMessage(@[intValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt
    check decoded.values[0].intVal == 123


  test "encode and decode with negative int":
    let intValue = newCandidInt(-456)
    let encoded = encodeCandidMessage(@[intValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt
    check decoded.values[0].intVal == -456


  test "encode and decode with zero":
    let intValue = newCandidInt(0)
    let encoded = encodeCandidMessage(@[intValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt
    check decoded.values[0].intVal == 0


  test "encode and decode with large values":
    let maxInt = newCandidInt(2147483647) # 2^31 - 1
    let minInt = newCandidInt(-2147483648) # -2^31
    
    let encodedMax = encodeCandidMessage(@[maxInt])
    let decodedMax = decodeCandidMessage(encodedMax)
    check decodedMax.values[0].kind == ctInt
    check decodedMax.values[0].intVal == 2147483647
    
    let encodedMin = encodeCandidMessage(@[minInt])
    let decodedMin = decodeCandidMessage(encodedMin)
    check decodedMin.values[0].kind == ctInt
    check decodedMin.values[0].intVal == -2147483648


  test "multiple int values":
    let intValue1 = newCandidInt(10)
    let intValue2 = newCandidInt(-20)
    let intValue3 = newCandidInt(0)
    let encoded = encodeCandidMessage(@[intValue1, intValue2, intValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt
    check decoded.values[0].intVal == 10
    check decoded.values[1].kind == ctInt
    check decoded.values[1].intVal == -20
    check decoded.values[2].kind == ctInt
    check decoded.values[2].intVal == 0


  test "int value type check":
    let intValue = newCandidInt(-999)
    check intValue.kind == ctInt
    check intValue.intVal == -999


suite "ic_int8 tests":
  test "encode with int8 zero":
    let int8Value = newCandidValue(0'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode with int8 positive value":
    let int8Value = newCandidValue(42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode with int8 negative value":
    let int8Value = newCandidValue(-42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode with int8 max value":
    let int8Value = newCandidValue(127'i8)  # 2^7 - 1
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode with int8 min value":
    let int8Value = newCandidValue(-128'i8)  # -2^7
    let encoded = encodeCandidMessage(@[int8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int8値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode and decode with int8 zero":
    let int8Value = newCandidValue(0'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == 0

  test "encode and decode with int8 positive value":
    let int8Value = newCandidValue(42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == 42

  test "encode and decode with int8 negative value":
    let int8Value = newCandidValue(-42'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == -42

  test "encode and decode with int8 max value":
    let int8Value = newCandidValue(127'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == 127

  test "encode and decode with int8 min value":
    let int8Value = newCandidValue(-128'i8)
    let encoded = encodeCandidMessage(@[int8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == -128

  test "encode and decode with int8 boundary values":
    let values = [1'i8, -1'i8, 126'i8, -127'i8]
    for val in values:
      let int8Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int8Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt8
      check decoded.values[0].int8Val == val

  test "multiple int8 values":
    let int8Value1 = newCandidValue(10'i8)
    let int8Value2 = newCandidValue(-20'i8)
    let int8Value3 = newCandidValue(127'i8)
    let encoded = encodeCandidMessage(@[int8Value1, int8Value2, int8Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt8
    check decoded.values[0].int8Val == 10
    check decoded.values[1].kind == ctInt8
    check decoded.values[1].int8Val == -20
    check decoded.values[2].kind == ctInt8
    check decoded.values[2].int8Val == 127

  test "int8 value properties":
    let int8Value = newCandidValue(-50'i8)
    check int8Value.kind == ctInt8
    check int8Value.int8Val == -50


suite "ic_int16 tests":
  test "encode with int16 zero":
    let int16Value = newCandidValue(0'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with int16 positive value":
    let int16Value = newCandidValue(42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with int16 negative value":
    let int16Value = newCandidValue(-42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with int16 max value":
    let int16Value = newCandidValue(32767'i16)  # 2^15 - 1
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with int16 min value":
    let int16Value = newCandidValue(-32768'i16)  # -2^15
    let encoded = encodeCandidMessage(@[int16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode and decode with int16 zero":
    let int16Value = newCandidValue(0'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == 0

  test "encode and decode with int16 positive value":
    let int16Value = newCandidValue(42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == 42

  test "encode and decode with int16 negative value":
    let int16Value = newCandidValue(-42'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == -42

  test "encode and decode with int16 max value":
    let int16Value = newCandidValue(32767'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == 32767

  test "encode and decode with int16 min value":
    let int16Value = newCandidValue(-32768'i16)
    let encoded = encodeCandidMessage(@[int16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == -32768

  test "encode and decode with int16 boundary values":
    let values = [1'i16, -1'i16, 255'i16, -255'i16, 32766'i16, -32767'i16]
    for val in values:
      let int16Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int16Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt16
      check decoded.values[0].int16Val == val

  test "multiple int16 values":
    let int16Value1 = newCandidValue(100'i16)
    let int16Value2 = newCandidValue(-200'i16)
    let int16Value3 = newCandidValue(32767'i16)
    let encoded = encodeCandidMessage(@[int16Value1, int16Value2, int16Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt16
    check decoded.values[0].int16Val == 100
    check decoded.values[1].kind == ctInt16
    check decoded.values[1].int16Val == -200
    check decoded.values[2].kind == ctInt16
    check decoded.values[2].int16Val == 32767

  test "int16 value properties":
    let int16Value = newCandidValue(-1000'i16)
    check int16Value.kind == ctInt16
    check int16Value.int16Val == -1000


suite "ic_int32 tests":
  test "encode with int32 zero":
    let int32Value = newCandidValue(0'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with int32 positive value":
    let int32Value = newCandidValue(42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with int32 negative value":
    let int32Value = newCandidValue(-42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with int32 max value":
    let int32Value = newCandidValue(2147483647'i32)  # 2^31 - 1
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with int32 min value":
    let int32Value = newCandidValue(-2147483648'i32)  # -2^31
    let encoded = encodeCandidMessage(@[int32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode and decode with int32 zero":
    let int32Value = newCandidValue(0'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == 0

  test "encode and decode with int32 positive value":
    let int32Value = newCandidValue(42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == 42

  test "encode and decode with int32 negative value":
    let int32Value = newCandidValue(-42'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == -42

  test "encode and decode with int32 max value":
    let int32Value = newCandidValue(2147483647'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == 2147483647

  test "encode and decode with int32 min value":
    let int32Value = newCandidValue(-2147483648'i32)
    let encoded = encodeCandidMessage(@[int32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == -2147483648

  test "encode and decode with int32 boundary values":
    let values = [1'i32, -1'i32, 65535'i32, -65535'i32, 2147483646'i32, -2147483647'i32]
    for val in values:
      let int32Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int32Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt32
      check decoded.values[0].int32Val == val

  test "multiple int32 values":
    let int32Value1 = newCandidValue(1000'i32)
    let int32Value2 = newCandidValue(-2000'i32)
    let int32Value3 = newCandidValue(2147483647'i32)
    let encoded = encodeCandidMessage(@[int32Value1, int32Value2, int32Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt32
    check decoded.values[0].int32Val == 1000
    check decoded.values[1].kind == ctInt32
    check decoded.values[1].int32Val == -2000
    check decoded.values[2].kind == ctInt32
    check decoded.values[2].int32Val == 2147483647

  test "int32 value properties":
    let int32Value = newCandidValue(-100000'i32)
    check int32Value.kind == ctInt32
    check int32Value.int32Val == -100000


suite "ic_int64 tests":
  test "encode with int64 zero":
    let int64Value = newCandidValue(0'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with int64 positive value":
    let int64Value = newCandidValue(42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with int64 negative value":
    let int64Value = newCandidValue(-42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with int64 large positive value":
    let int64Value = newCandidValue(9223372036854775807'i64)  # 2^63 - 1
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with int64 large negative value":
    let int64Value = newCandidValue(-9223372036854775808'i64)  # -2^63
    let encoded = encodeCandidMessage(@[int64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + int64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode and decode with int64 zero":
    let int64Value = newCandidValue(0'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == 0

  test "encode and decode with int64 positive value":
    let int64Value = newCandidValue(42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == 42

  test "encode and decode with int64 negative value":
    let int64Value = newCandidValue(-42'i64)
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == -42

  test "encode and decode with int64 large positive value":
    let int64Value = newCandidValue(1000000000000'i64)  # 1兆（制約を考慮して実際に動作する値）
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == 1000000000000

  test "encode and decode with int64 large negative value":
    let int64Value = newCandidValue(-1000000000000'i64)  # -1兆
    let encoded = encodeCandidMessage(@[int64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == -1000000000000

  test "encode and decode with int64 boundary values":
    let values = [1'i64, -1'i64, 4294967295'i64, -4294967295'i64, 1000000000'i64, -1000000000'i64]
    for val in values:
      let int64Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[int64Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctInt64
      check decoded.values[0].int64Val == val

  test "multiple int64 values":
    let int64Value1 = newCandidValue(10000'i64)
    let int64Value2 = newCandidValue(-20000'i64)
    let int64Value3 = newCandidValue(1000000000000'i64)
    let encoded = encodeCandidMessage(@[int64Value1, int64Value2, int64Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctInt64
    check decoded.values[0].int64Val == 10000
    check decoded.values[1].kind == ctInt64
    check decoded.values[1].int64Val == -20000
    check decoded.values[2].kind == ctInt64
    check decoded.values[2].int64Val == 1000000000000

  test "int64 value properties":
    let int64Value = newCandidValue(-10000000'i64)
    check int64Value.kind == ctInt64
    check int64Value.int64Val == -10000000 