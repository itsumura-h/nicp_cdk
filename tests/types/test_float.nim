discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_float.nim

import unittest
import std/math
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "Float Candid Type Tests":
  test "newCandidFloat with float":
    let value = newCandidFloat(3.14159)
    check value.kind == ctFloat
    check abs(value.floatVal - 3.14159) < 0.00001

  test "float encoding and decoding":
    let originalValue = 1.23456
    let candidValue = newCandidFloat(originalValue)
    
    let encoded = encodeCandidMessage(@[candidValue])
    check encoded.len > 0
    
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    # floatはfloat32として扱われる
    check decoded.values[0].kind == ctFloat32
    check abs(decoded.values[0].float32Val - float32(originalValue)) < 0.00001'f32

  test "float boundary values":
    # 正の小さな値
    block:
      let value = newCandidFloat(0.000001)
      check value.kind == ctFloat
      check abs(value.floatVal - 0.000001) < 0.0000001
    
    # 負の値
    block:
      let value = newCandidFloat(-123.456)
      check value.kind == ctFloat
      check abs(value.floatVal - (-123.456)) < 0.001
    
    # ゼロ
    block:
      let value = newCandidFloat(0.0)
      check value.kind == ctFloat
      check abs(value.floatVal - 0.0) < 0.00001

  test "float encoding size":
    let value = newCandidFloat(42.0)
    let encoded = encodeCandidMessage(@[value])
    # floatはfloat32として扱われるため、DIDL0ヘッダー(4) + 型テーブル(3) + float32値(4) = 11バイト
    check encoded.len == 11

  test "multiple float values":
    let values = @[
      newCandidFloat(1.1),
      newCandidFloat(2.2),
      newCandidFloat(3.3)
    ]
    
    let encoded = encodeCandidMessage(values)
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 3
    # floatはfloat32として扱われる
    check decoded.values[0].kind == ctFloat32
    check decoded.values[1].kind == ctFloat32
    check decoded.values[2].kind == ctFloat32
    check abs(decoded.values[0].float32Val - 1.1'f32) < 0.01'f32
    check abs(decoded.values[1].float32Val - 2.2'f32) < 0.01'f32
    check abs(decoded.values[2].float32Val - 3.3'f32) < 0.01'f32

  test "float large values":
    # 大きな正の値
    block:
      let value = newCandidFloat(12345.6789)
      check value.kind == ctFloat
      check abs(value.floatVal - 12345.6789) < 0.01
    
    # 大きな負の値
    block:
      let value = newCandidFloat(-98765.4321)
      check value.kind == ctFloat
      check abs(value.floatVal - (-98765.4321)) < 0.01

  test "float to float32 conversion in candid":
    # floatがfloat32として扱われることを確認
    let originalValue = 999.999
    let candidValue = newCandidFloat(originalValue)
    
    let encoded = encodeCandidMessage(@[candidValue])
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values[0].kind == ctFloat32
    # float32の精度で比較
    check abs(decoded.values[0].float32Val - float32(originalValue)) < 0.001'f32


suite "Float32 Candid Type Tests":
  test "newCandidValue with float32":
    let value = newCandidValue(3.14159'f32)
    check value.kind == ctFloat32
    check abs(value.float32Val - 3.14159'f32) < 0.00001'f32

  test "newCandidFloat with float32":
    let value = newCandidFloat(2.5'f32)
    check value.kind == ctFloat
    check abs(value.floatVal - 2.5'f32) < 0.00001'f32

  test "float32 encoding and decoding":
    let originalValue = 1.23456'f32
    let candidValue = newCandidValue(originalValue)
    
    let encoded = encodeCandidMessage(@[candidValue])
    check encoded.len > 0
    
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctFloat32
    check abs(decoded.values[0].float32Val - originalValue) < 0.00001'f32

  test "float32 boundary values":
    # 正の小さな値
    block:
      let value = newCandidValue(0.000001'f32)
      check value.kind == ctFloat32
      check abs(value.float32Val - 0.000001'f32) < 0.0000001'f32
    
    # 負の値
    block:
      let value = newCandidValue(-123.456'f32)
      check value.kind == ctFloat32
      check abs(value.float32Val - (-123.456'f32)) < 0.001'f32
    
    # ゼロ
    block:
      let value = newCandidValue(0.0'f32)
      check value.kind == ctFloat32
      check abs(value.float32Val - 0.0'f32) < 0.00001'f32

  test "float32 encoding size":
    let value = newCandidValue(42.0'f32)
    let encoded = encodeCandidMessage(@[value])
    # DIDL0ヘッダー(4) + 型テーブル(3) + float32値(4) = 11バイト
    check encoded.len == 11

  test "multiple float32 values":
    let values = @[
      newCandidValue(1.1'f32),
      newCandidValue(2.2'f32),
      newCandidValue(3.3'f32)
    ]
    
    let encoded = encodeCandidMessage(values)
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 3
    check abs(decoded.values[0].float32Val - 1.1'f32) < 0.01'f32
    check abs(decoded.values[1].float32Val - 2.2'f32) < 0.01'f32
    check abs(decoded.values[2].float32Val - 3.3'f32) < 0.01'f32

  test "float32 large values":
    # 大きな正の値
    block:
      let value = newCandidValue(12345.6789'f32)
      check value.kind == ctFloat32
      check abs(value.float32Val - 12345.6789'f32) < 0.01'f32
    
    # 大きな負の値
    block:
      let value = newCandidValue(-98765.4321'f32)
      check value.kind == ctFloat32
      check abs(value.float32Val - (-98765.4321'f32)) < 0.01'f32


suite "Float64 Candid Type Tests":
  test "newCandidValue with float64":
    let value = newCandidFloat64(3.141592653589793)
    check value.kind == ctFloat64
    check abs(value.float64Val - 3.141592653589793) < 0.000000000001

  test "newCandidFloat64 constructor":
    let value = newCandidFloat64(2.718281828459045)
    check value.kind == ctFloat64
    check abs(value.float64Val - 2.718281828459045) < 0.000000000001

  test "float64 encoding and decoding":
    let originalValue: float64 = 1.23456789012345
    let candidValue = newCandidFloat64(originalValue)
    
    let encoded = encodeCandidMessage(@[candidValue])
    check encoded.len > 0
    
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctFloat64
    check abs(decoded.values[0].float64Val - originalValue) < 0.000000000001

  test "float64 boundary values":
    # 正の小さな値
    block:
      let value = newCandidFloat64(0.000000000001)
      check value.kind == ctFloat64
      check abs(value.float64Val - 0.000000000001) < 0.0000000000001
    
    # 負の値
    block:
      let value = newCandidFloat64(-123.456789012345)
      check value.kind == ctFloat64
      check abs(value.float64Val - (-123.456789012345)) < 0.000000000001
    
    # ゼロ
    block:
      let value = newCandidFloat64(0.0)
      check value.kind == ctFloat64
      check abs(value.float64Val - 0.0) < 0.000000000001

  test "float64 encoding size":
    let value = newCandidFloat64(42.0)
    let encoded = encodeCandidMessage(@[value])
    # DIDL0ヘッダー(4) + 型テーブル(3) + float64値(8) = 15バイト
    check encoded.len == 15

  test "multiple float64 values":
    let values = @[
      newCandidFloat64(1.11111111111111),
      newCandidFloat64(2.22222222222222),
      newCandidFloat64(3.33333333333333)
    ]
    
    let encoded = encodeCandidMessage(values)
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 3
    check abs(decoded.values[0].float64Val - 1.11111111111111) < 0.000000000001
    check abs(decoded.values[1].float64Val - 2.22222222222222) < 0.000000000001
    check abs(decoded.values[2].float64Val - 3.33333333333333) < 0.000000000001

  test "float64 large values":
    # 大きな正の値
    block:
      let value = newCandidFloat64(1234567890.123456789)
      check value.kind == ctFloat64
      check abs(value.float64Val - 1234567890.123456789) < 0.000001
    
    # 大きな負の値
    block:
      let value = newCandidFloat64(-9876543210.987654321)
      check value.kind == ctFloat64
      check abs(value.float64Val - (-9876543210.987654321)) < 0.000001

  test "float64 precision test":
    # float64の高精度をテスト
    let highPrecisionValue: float64 = 0.1234567890123456789
    let value = newCandidFloat64(highPrecisionValue)
    check value.kind == ctFloat64
    check abs(value.float64Val - highPrecisionValue) < 0.0000000000000001

  test "newCandidValue with explicit float64 cast":
    # 明示的なキャストでnewCandidValueをテスト
    let value = newCandidValue(float64(99.999999999999999))
    check value.kind == ctFloat64
    check abs(value.float64Val - 99.999999999999999) < 0.000000000001 