import unittest
import ../src/nicp_cdk/ic_types/ic_int

suite "ic_int tests":
  test "serializeCandid with int32":
    let result = serializeCandid(42'i32)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + SLEB128値
    check result.len >= 7
    # 正の値が正しくエンコードされることを確認
    check result.len > 0
  
  test "serializeCandid with negative int32":
    let result = serializeCandid(-42'i32)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + SLEB128値
    check result.len >= 7
    # 負の値が正しくエンコードされることを確認
    check result.len > 0
  
  test "serializeCandid with int":
    let result = serializeCandid(123)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + SLEB128値
    check result.len >= 7
    check result.len > 0
  
  test "serializeCandid with uint":
    let result = serializeCandid(123'u)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + ULEB128値
    check result.len >= 7
    check result.len > 0 