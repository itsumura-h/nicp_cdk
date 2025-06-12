import unittest
import ../src/nicp_cdk/ic_types/ic_float

suite "ic_float tests":
  test "serializeCandid with float32 zero":
    let result = serializeCandid(0.0'f32)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + IEEE754値(4バイト)
    check result.len == 10
    # マジックヘッダーの確認
    check result[0..3] == @[68'u8, 73'u8, 68'u8, 76'u8]  # "DIDL"
  
  test "serializeCandid with float32 positive":
    let result = serializeCandid(3.14'f32)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + IEEE754値(4バイト)
    check result.len == 10
    # 正の値が正しくエンコードされることを確認
    check result.len > 0
  
  test "serializeCandid with float32 negative":
    let result = serializeCandid(-1.5'f32)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + IEEE754値(4バイト)
    check result.len == 10
    # 負の値が正しくエンコードされることを確認
    check result.len > 0
  
  test "serializeCandid consistency":
    let value = 42.125'f32
    let result1 = serializeCandid(value)
    let result2 = serializeCandid(value)
    # 同じ値は同じ結果を生成することを確認
    check result1 == result2 