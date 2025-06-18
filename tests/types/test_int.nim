discard """
cmd: nim c --skipUserCfg tests/types/test_int.nim
"""
# nim c -r --skipUserCfg tests/types/test_int.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_int tests":
  test "serializeCandid with positive int":
    let intValue = newCandidInt(42)
    let encoded = encodeCandidMessage(@[intValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト（小さい値の場合）
    check encoded.len == 8


  test "serializeCandid with negative int":
    let intValue = newCandidInt(-42)
    let encoded = encodeCandidMessage(@[intValue])
    check encoded.len == 8


  test "serializeCandid with zero":
    let intValue = newCandidInt(0)
    let encoded = encodeCandidMessage(@[intValue])
    check encoded.len == 8


  test "serializeCandid with large positive int":
    let intValue = newCandidInt(1000000)
    let encoded = encodeCandidMessage(@[intValue])
    # 大きな値はより多くのバイトを使用
    check encoded.len > 8


  test "serializeCandid with large negative int":
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