import unittest
import std/math
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "Float32 Candid Type Tests":
  test "newCandidValue with float32":
    let value = newCandidValue(3.14159'f32)
    check value.kind == ctFloat32
    check abs(value.float32Val - 3.14159'f32) < 0.00001'f32

  test "newCandidFloat with float32":
    let value = newCandidFloat(2.5'f32)
    check value.kind == ctFloat32
    check abs(value.float32Val - 2.5'f32) < 0.00001'f32

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

when isMainModule:
  # テスト実行
  echo "Running float32 tests..." 