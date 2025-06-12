import unittest
import ../src/nicp_cdk/ic_types/ic_bool

suite "ic_bool tests":
  test "serializeCandid with true":
    let result = serializeCandid(true)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 値(1バイト)
    check result.len == 7
    # 最後のバイトがtrueを表す1であることを確認
    check result[^1] == 1'u8
  
  test "serializeCandid with false":
    let result = serializeCandid(false)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 値(1バイト)
    check result.len == 7
    # 最後のバイトがfalseを表す0であることを確認
    check result[^1] == 0'u8 