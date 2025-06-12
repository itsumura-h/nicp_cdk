discard """
  cmd: "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/test_candid_record.nim

import std/unittest
import std/options
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/ic_record
import ../src/nicp_cdk/ic_types/ic_principal
import ../src/nicp_cdk/ic_types/ic_variant
import ../src/nicp_cdk/ic_types/ic_service
import ../src/nicp_cdk/ic_types/candid_funcs


# テストスイート: CandidValue %*マクロのテスト
suite "CandidValue %*macro tests":
  
  test "基本型のテスト":
    let basicExample = %*{
      "name": "Alice",
      "age": 30,
      "isActive": true,
      "score": 95.5,
      "nilField": nil
    }
    
    check:
      basicExample["name"].getStr() == "Alice"
      basicExample["age"].getInt() == 30
      basicExample["isActive"].getBool() == true
      basicExample["score"].getFloat64() == 95.5
      basicExample["nilField"].isNull() == true
  
  test "Principal型のテスト":
    let owner = Principal.fromText("aaaaa-aa")
    let canister = Principal.fromText("w7x7r-cok77-xa")
    let principalExample = %*{
      "owner": owner,
      "canister": canister
    }
    
    check:
      principalExample["owner"].getPrincipal() == owner
      principalExample["canister"].getPrincipal() == canister
      principalExample["owner"].isPrincipal() == true
  
  test "Blob型のテスト":
    let blobExample = %*{
      "data": @[1u8, 2u8, 3u8, 4u8, 5u8].asBlob,
      "signature": @[0x41u8, 0x42u8, 0x43u8].asBlob
    }
    
    check:
      blobExample["data"].getBytes() == @[1u8, 2u8, 3u8, 4u8, 5u8]
      blobExample["signature"].getBytes() == @[0x41u8, 0x42u8, 0x43u8]
      blobExample["data"].isBlob() == true
  
  test "配列のテスト":
    let arrayExample = %*{
      "numbers": [1, 2, 3, 4],
      "names": ["Alice", "Bob", "Charlie"],
      "mixed": [42, "text", true]
    }
    
    # 基本的な配列操作のテスト
    check:
      arrayExample["numbers"].len() == 4
      arrayExample["numbers"][0].getInt() == 1
      arrayExample["numbers"][3].getInt() == 4
      arrayExample["names"].len() == 3
      arrayExample["names"][0].getStr() == "Alice"
      arrayExample["mixed"].len() == 3
      arrayExample["mixed"][0].getInt() == 42
      arrayExample["mixed"][1].getStr() == "text"
      arrayExample["mixed"][2].getBool() == true
    
    # getArray関数のテスト
    let numbersArray = arrayExample["numbers"].getArray()
    let namesArray = arrayExample["names"].getArray()
    let mixedArray = arrayExample["mixed"].getArray()
    
    check:
      numbersArray.len == 4
      numbersArray[0].getInt() == 1
      numbersArray[3].getInt() == 4
      namesArray.len == 3
      namesArray[0].getStr() == "Alice"
      namesArray[2].getStr() == "Charlie"
      mixedArray.len == 3
      mixedArray[0].getInt() == 42
      mixedArray[1].getStr() == "text"
      mixedArray[2].getBool() == true
  
  test "Option型のテスト":
    let optionExample = %*{
      "nickname": some("Ali"),
      "middleName": none(string),
      "rating": some(5),
      "name": some("Bob"),
      "score": none(int),
      "flag": some(true)
    }
    
    check:
      optionExample["nickname"].isSome() == true
      optionExample["nickname"].getOpt().getStr() == "Ali"
      optionExample["middleName"].isNone() == true
      optionExample["rating"].isSome() == true
      optionExample["rating"].getOpt().getInt() == 5
      optionExample["name"].isSome() == true
      optionExample["name"].getOpt().getStr() == "Bob"
      optionExample["score"].isNone() == true
      optionExample["flag"].isSome() == true
      optionExample["flag"].getOpt().getBool() == true

  test "Float32/Float64型のテスト":
    let floatExample = %*{
      "float32": newCFloat32(3.14),
      "float64": 3.14159265359,
      "negative32": newCFloat32(-1.5),
      "negative64": -2.71828182846
    }
    
    check:
      floatExample["float32"].getFloat32() == 3.14'f32
      floatExample["float64"].getFloat64() == 3.14159265359
      floatExample["negative32"].getFloat32() == -1.5'f32
      floatExample["negative64"].getFloat64() == -2.71828182846
      floatExample["float32"].isFloat32() == true
      floatExample["float64"].isFloat64() == true

  test "Variant型のテスト":
    let variantExample = %*{
      "success": newCVariant("success", newCText("Operation completed")),
      "error": newCVariant("error", newCText("Something went wrong")),
      "empty": newCVariant("empty")
    }
    
    let successVariant = variantExample["success"].getVariant()
    let errorVariant = variantExample["error"].getVariant()
    let emptyVariant = variantExample["empty"].getVariant()
    
    check:
      successVariant.tag == "success"
      successVariant.value.getStr() == "Operation completed"
      errorVariant.tag == "error"
      errorVariant.value.getStr() == "Something went wrong"
      emptyVariant.tag == "empty"
      emptyVariant.value.isNull() == true
      variantExample["success"].isVariant() == true

  test "Func型のテスト":
    let funcExample = %*{
      "callback": newCFunc("aaaaa-aa", "onComplete"),
      "handler": newCFunc("w7x7r-cok77-xa", "processData")
    }
    
    check:
      $funcExample["callback"].getFuncPrincipal() == "aaaaa-aa"
      funcExample["callback"].getFuncMethod() == "onComplete"
      $funcExample["handler"].getFuncPrincipal() == "w7x7r-cok77-xa"
      funcExample["handler"].getFuncMethod() == "processData"
      funcExample["callback"].isFunc() == true

  test "Service型のテスト":
    let serviceExample = %*{
      "ledger": newCService("ryjl3-tyaaa-aaaaa-aaaba-cai"),
      "registry": newCService("rrkah-fqaaa-aaaaa-aaaaq-cai")
    }
    
    check:
      serviceExample["ledger"].getService() == Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")
      serviceExample["registry"].getService() == Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
      serviceExample["ledger"].isService() == true

  test "複合型のテスト":
    let complexExample = %*{
      "user": {
        "name": "Alice",
        "age": 30,
        "scores": [95.5, 88.0, 92.5],
        "active": true,
        "metadata": {
          "lastLogin": "2024-03-20",
          "permissions": ["read", "write"],
          "settings": {
            "theme": "dark",
            "notifications": true
          }
        }
      },
      "status": newCVariant("success", newCText("User data retrieved")),
      "timestamp": 1710936000,
      "services": [
        newCService("ryjl3-tyaaa-aaaaa-aaaba-cai"),
        newCService("rrkah-fqaaa-aaaaa-aaaaq-cai")
      ],
      "callbacks": {
        "onSuccess": newCFunc("aaaaa-aa", "handleSuccess"),
        "onError": newCFunc("aaaaa-aa", "handleError")
      }
    }
    
    check:
      complexExample["user"]["name"].getStr() == "Alice"
      complexExample["user"]["age"].getInt() == 30
      complexExample["user"]["scores"].len() == 3
      complexExample["user"]["scores"][0].getFloat64() == 95.5
      complexExample["user"]["active"].getBool() == true
      complexExample["user"]["metadata"]["lastLogin"].getStr() == "2024-03-20"
      complexExample["user"]["metadata"]["permissions"].len() == 2
      complexExample["user"]["metadata"]["permissions"][0].getStr() == "read"
      complexExample["user"]["metadata"]["settings"]["theme"].getStr() == "dark"
      complexExample["status"].getVariant().tag == "success"
      complexExample["status"].getVariant().value.getStr() == "User data retrieved"
      complexExample["timestamp"].getInt() == 1710936000
      complexExample["services"].len() == 2
      complexExample["services"][0].getService() == Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")
      complexExample["callbacks"]["onSuccess"].getFuncMethod() == "handleSuccess"
      complexExample["callbacks"]["onError"].getFuncMethod() == "handleError"

  test "asBlob拡張メソッドのテスト":
    # asBlobメソッドがseq[uint8]をBlob型として明示的に変換することを確認
    let asBlobExample = %*{
      "blobValue": @[0x01u8, 0x02u8, 0x03u8].asBlob,
      "arrayValue": [1, 2, 3]  # 通常の配列として扱われる
    }
    
    check:
      asBlobExample["blobValue"].getBytes() == @[0x01u8, 0x02u8, 0x03u8]
      asBlobExample["blobValue"].isBlob() == true
      asBlobExample["arrayValue"].len() == 3
      asBlobExample["arrayValue"].isArray() == true
      asBlobExample["arrayValue"][0].getInt() == 1
      asBlobExample["arrayValue"][1].getInt() == 2
      asBlobExample["arrayValue"][2].getInt() == 3

  test "Variant.new()構文のテスト":
    # 新しいVariant.new()構文が正しく動作することを確認
    let successVariant = Variant.new("success", newCText("Operation completed"))
    let errorVariant = Variant.new("error", newCText("Something went wrong"))
    let emptyVariant = Variant.new("empty")
    
    let variantNewExample = %*{
      "success": successVariant,
      "error": errorVariant,
      "empty": emptyVariant
    }
    
    let successVariantResult = variantNewExample["success"].getVariant()
    let errorVariantResult = variantNewExample["error"].getVariant()
    let emptyVariantResult = variantNewExample["empty"].getVariant()
    
    check:
      successVariantResult.tag == "success"
      successVariantResult.value.getStr() == "Operation completed"
      errorVariantResult.tag == "error"
      errorVariantResult.value.getStr() == "Something went wrong"
      emptyVariantResult.tag == "empty"
      emptyVariantResult.value.isNull() == true
      variantNewExample["success"].isVariant() == true
      variantNewExample["error"].isVariant() == true
      variantNewExample["empty"].isVariant() == true

  test "Service.new()構文のテスト":
    # 新しいService.new()構文が正しく動作することを確認
    let ledgerService = Service.new("ryjl3-tyaaa-aaaaa-aaaba-cai")
    let registryService = Service.new("rrkah-fqaaa-aaaaa-aaaaq-cai")
    
    let serviceNewExample = %*{
      "ledger": ledgerService,
      "registry": registryService
    }
    
    check:
      serviceNewExample["ledger"].getService() == Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")
      serviceNewExample["registry"].getService() == Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
      serviceNewExample["ledger"].isService() == true
      serviceNewExample["registry"].isService() == true

  test("t-ecdsa public key args"):
    type Curve = enum
      secp256k1
    
    let caller = Principal.fromText("aaaaa-aa")
    let derivationPath = caller.bytes
    let arg = %*{
      "canister_id": none(Principal),
      "derivation_path": derivationPath.asBlob(),
      "key_id": {
        "curve": Curve.secp256k1,
        "name": "dfx_test_key"
      }
    }
    echo "arg: ", $arg
    check:
      arg["canister_id"].isNull() == true
      arg["derivation_path"].getBytes() == derivationPath
      arg["key_id"]["curve"].getEnum(Curve) == Curve.secp256k1
      arg["key_id"]["name"].getStr() == "dfx_test_key"
