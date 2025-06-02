# nim c -r --skipUserCfg tests/test_candid_record.nim

import std/unittest
import std/sequtils
import std/strutils  # for string contains
import std/options
import ../src/nicp_cdk/ic_types/ic_principal
import ../src/nicp_cdk/ic_types/ic_record

# テストスイート: CandidValue %*マクロのテスト
suite "CandidValue %*macro tests":
  
  test "基本型のテスト":
    let basicExample = %*{
      "name": "Alice",
      "age": 30,
      "isActive": true,
      "score": 95.5,
      "nullField": newCNull(),
      "nilField": nil
    }
    
    check:
      basicExample["name"].getStr() == "Alice"
      basicExample["age"].getInt() == 30
      basicExample["isActive"].getBool() == true
      basicExample["score"].getFloat64() == 95.5
      basicExample["nullField"].isNull() == true
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
      "data": newCBlob(@[1u8, 2u8, 3u8, 4u8, 5u8]),
      "signature": newCBlob(@[0x41u8, 0x42u8, 0x43u8])
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
