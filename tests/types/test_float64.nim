import unittest
import std/math
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

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

when isMainModule:
  # テスト実行
  echo "Running float64 tests..." 