discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_principal.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_principal tests":
  test "newCandidValue with Principal.fromText":
    let principal = Principal.fromText("aaaaa-aa")
    let principalValue = newCandidValue(principal)
    check principalValue.kind == ctPrincipal
    check principalValue.principalVal.text == "aaaaa-aa"


  test "newCandidValue with governance canister principal":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let principalValue = newCandidValue(principal)
    check principalValue.kind == ctPrincipal
    check principalValue.principalVal.text == "rrkah-fqaaa-aaaaa-aaaaq-cai"


  test "encode with management canister principal":
    let principal = Principal.fromText("aaaaa-aa")
    let principalValue = newCandidValue(principal)
    let encoded = encodeCandidMessage(@[principalValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + IDフォーム(1バイト) + 長さ(ULEB128) + バイト列
    check encoded.len >= 7
    # マジックヘッダーの確認
    check encoded[0..3] == @[68'u8, 73'u8, 68'u8, 76'u8]  # "DIDL"


  test "encode with long principal":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let principalValue = newCandidValue(principal)
    let encoded = encodeCandidMessage(@[principalValue])
    # 長いprincipalでもエンコードできることを確認
    check encoded.len >= 7
    # マジックヘッダーの確認
    check encoded[0..3] == @[68'u8, 73'u8, 68'u8, 76'u8]  # "DIDL"


  test "encode and decode with management canister principal":
    let principal = Principal.fromText("aaaaa-aa")
    let principalValue = newCandidValue(principal)
    let encoded = encodeCandidMessage(@[principalValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.text == "aaaaa-aa"


  test "encode and decode with governance canister principal":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let principalValue = newCandidValue(principal)
    let encoded = encodeCandidMessage(@[principalValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.text == "rrkah-fqaaa-aaaaa-aaaaq-cai"


  test "multiple principal values":
    let principal1 = Principal.fromText("aaaaa-aa")
    let principal2 = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let principalValue1 = newCandidValue(principal1)
    let principalValue2 = newCandidValue(principal2)
    let encoded = encodeCandidMessage(@[principalValue1, principalValue2])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 2
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.text == "aaaaa-aa"
    check decoded.values[1].kind == ctPrincipal
    check decoded.values[1].principalVal.text == "rrkah-fqaaa-aaaaa-aaaaq-cai"


  test "principal from blob conversion":
    let testBytes = @[1'u8, 2'u8, 3'u8, 4'u8]
    let principal = Principal.fromBlob(testBytes)
    let principalValue = newCandidValue(principal)
    check principalValue.kind == ctPrincipal
    check principalValue.principalVal.bytes == testBytes


  test "round trip conversion with blob":
    let testBytes = @[0x01'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8]
    let principal = Principal.fromBlob(testBytes)
    let principalValue = newCandidValue(principal)
    let encoded = encodeCandidMessage(@[principalValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.bytes == testBytes


  test "principal type check":
    let principal = Principal.fromText("aaaaa-aa")
    let principalValue = newCandidValue(principal)
    check principalValue.kind == ctPrincipal


  test "anonymous principal":
    # 匿名principalは長さ0のバイト列で表される
    let anonymousPrincipal = Principal.fromBlob(@[])
    let principalValue = newCandidValue(anonymousPrincipal)
    check principalValue.kind == ctPrincipal
    check principalValue.principalVal.bytes.len == 0 