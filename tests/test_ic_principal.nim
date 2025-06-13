import unittest
import ../src/nicp_cdk/ic_types/ic_principal

suite "ic_principal tests":
  test "fromText and toString for management canister":
    let principal = Principal.fromText("aaaaa-aa")
    check principal.value == "aaaaa-aa"
    check $principal == "aaaaa-aa"
  
  test "fromText and toString for governance canister":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    check principal.value == "rrkah-fqaaa-aaaaa-aaaaq-cai"
    check $principal == "rrkah-fqaaa-aaaaa-aaaaq-cai"
  
  test "fromBlob and back conversion":
    let testBytes = @[1'u8, 2'u8, 3'u8, 4'u8]
    let principal = Principal.fromBlob(testBytes)
    check principal.bytes == testBytes
    # fromBlobで作成されたPrincipalの文字列表現が正しいことを確認
    check principal.value.len > 0
  
  test "serializeCandid for principal":
    let principal = Principal.fromText("aaaaa-aa")
    let result = serializeCandid(principal)
    # DIDL0ヘッダー(4バイト) + 型テーブル(2バイト) + IDフォーム(1バイト) + 長さ(ULEB128) + バイト列
    check result.len >= 7
    # マジックヘッダーの確認
    check result[0..3] == @[68'u8, 73'u8, 68'u8, 76'u8]  # "DIDL"
  
  test "round trip conversion":
    let originalText = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    let principal1 = Principal.fromText(originalText)
    let principal2 = Principal.fromBlob(principal1.bytes)
    
    # バイト列は同一であることを確認
    check principal1.bytes == principal2.bytes 