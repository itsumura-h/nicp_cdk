import unittest
import ../src/nicp_cdk/ic_types/ic_text

suite "ic_text tests":
  test "serializeCandid with simple text":
    let result = serializeCandid("hello")
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 長さ(1バイト) + UTF-8文字列(5バイト)
    check result.len == 12
    # 長さ情報(5)が6番目のバイトに含まれていることを確認
    check result[6] == 5'u8
    # 文字列の内容確認（7番目のバイトから文字列開始）
    let textBytes = result[7..^1]
    check textBytes == @[104'u8, 101'u8, 108'u8, 108'u8, 111'u8]  # 'h','e','l','l','o'
  
  test "serializeCandid with empty text":
    let result = serializeCandid("")
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + 長さ(1バイト)
    check result.len == 7
    # 空文字列の長さは0
    check result[^1] == 0'u8
  
  test "readText functionality":
    let data = @[5'u8, 'h'.byte, 'e'.byte, 'l'.byte, 'l'.byte, 'o'.byte]
    var offset = 0
    let result = readText(data, offset)
    check result == "hello"
    check offset == 6  # 長さ(1バイト) + 文字列(5バイト) 