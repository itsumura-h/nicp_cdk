import unittest
import ../src/nicp_cdk/ic_types/ic_empty

suite "ic_empty tests":
  test "serializeCandid for empty response":
    let result = serializeCandid()
    # DIDL0ヘッダー(4バイト) + 空の値数(1バイト)
    check result.len == 5
    # マジックヘッダーの確認
    check result[0..3] == @[68'u8, 73'u8, 68'u8, 76'u8]  # "DIDL"
    # 最後のバイトが0（空）であることを確認
    check result[4] == 0'u8 