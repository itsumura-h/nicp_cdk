discard """
cmd: nim c --skipUserCfg tests/types/test_func.nim
"""
# nim c -r --skipUserCfg tests/types/test_func.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_func tests":
  test "encode with simple func":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "test_method")
    let encoded = encodeCandidMessage(@[funcValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(複合型なので可変) + principal length + principal bytes + method name length + method name bytes
    check encoded.len > 10  # 少なくとも10バイト以上


  test "encode with management canister func":
    let principal = Principal.fromText("aaaaa-aa")  # management canister
    let funcValue = newCandidFunc(principal, "raw_rand")
    let encoded = encodeCandidMessage(@[funcValue])
    check encoded.len > 10


  test "encode with long method name":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let funcValue = newCandidFunc(principal, "very_long_method_name_for_testing_purposes")
    let encoded = encodeCandidMessage(@[funcValue])
    check encoded.len > 20


  test "encode and decode with simple func":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "test_method")
    let encoded = encodeCandidMessage(@[funcValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal.value
    check decoded.values[0].funcVal.methodName == "test_method"


  test "encode and decode with canister func":
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let funcValue = newCandidFunc(principal, "get_balance")
    let encoded = encodeCandidMessage(@[funcValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal.value
    check decoded.values[0].funcVal.methodName == "get_balance"


  test "encode and decode with empty method name":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "")
    let encoded = encodeCandidMessage(@[funcValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal.value
    check decoded.values[0].funcVal.methodName == ""


  test "multiple func values":
    let principal1 = Principal.fromText("aaaaa-aa")
    let principal2 = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let funcValue1 = newCandidFunc(principal1, "method1")
    let funcValue2 = newCandidFunc(principal2, "method2")
    let funcValue3 = newCandidFunc(principal1, "method3")
    let encoded = encodeCandidMessage(@[funcValue1, funcValue2, funcValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal1.value
    check decoded.values[0].funcVal.methodName == "method1"
    check decoded.values[1].kind == ctFunc
    check decoded.values[1].funcVal.principal.value == principal2.value
    check decoded.values[1].funcVal.methodName == "method2"
    check decoded.values[2].kind == ctFunc
    check decoded.values[2].funcVal.principal.value == principal1.value
    check decoded.values[2].funcVal.methodName == "method3"


  test "func with different principal types":
    # 異なる種類のPrincipalでのテスト
    let principals = [
      Principal.fromText("aaaaa-aa"),  # management canister
      Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),  # typical canister
      Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")  # ledger canister
    ]
    let methodNames = ["method1", "get_data", "update_state"]
    
    for i, principal in principals:
      let funcValue = newCandidFunc(principal, methodNames[i])
      let encoded = encodeCandidMessage(@[funcValue])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctFunc
      check decoded.values[0].funcVal.principal.value == principal.value
      check decoded.values[0].funcVal.methodName == methodNames[i]


  test "func value type check":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "test_method")
    check funcValue.kind == ctFunc
    check funcValue.funcVal.principal.value == principal.value
    check funcValue.funcVal.methodName == "test_method"


  test "func with unicode method name":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "テスト_メソッド")
    let encoded = encodeCandidMessage(@[funcValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal.value
    check decoded.values[0].funcVal.methodName == "テスト_メソッド"


  test "func with special characters in method name":
    let principal = Principal.fromText("aaaaa-aa")
    let funcValue = newCandidFunc(principal, "method_with-special.chars:123")
    let encoded = encodeCandidMessage(@[funcValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctFunc
    check decoded.values[0].funcVal.principal.value == principal.value
    check decoded.values[0].funcVal.methodName == "method_with-special.chars:123" 