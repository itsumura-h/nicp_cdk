# nim c -r --skipUserCfg tests/test_candid_record.nim

import std/unittest
import std/sequtils
import std/strutils  # for string contains
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
  
  # test "Principal型のテスト":
  #   let principalExample = %*{
  #     "owner": cprincipal("aaaaa-aa"),
  #     "canister": cprincipal("w7x7r-cok77-xa")
  #   }
    
  #   check:
  #     principalExample["owner"].asPrincipal() == "aaaaa-aa"
  #     principalExample["canister"].asPrincipal() == "w7x7r-cok77-xa"
  #     principalExample["owner"].isPrincipal() == true
  
  # test "Blob型のテスト":
  #   let blobExample = %*{
  #     "data": cblob([1, 2, 3, 4, 5]),
  #     "signature": cblob([0x41, 0x42, 0x43])
  #   }
    
  #   check:
  #     blobExample["data"].getBytes() == @[1u8, 2u8, 3u8, 4u8, 5u8]
  #     blobExample["signature"].getBytes() == @[0x41u8, 0x42u8, 0x43u8]
  #     blobExample["data"].isBlob() == true
  
  # test "配列のテスト":
  #   let arrayExample = %*{
  #     "numbers": [1, 2, 3, 4],
  #     "names": ["Alice", "Bob", "Charlie"],
  #     "mixed": [42, "text", true]
  #   }
    
  #   check:
  #     arrayExample["numbers"].len() == 4
  #     arrayExample["numbers"][0].getInt() == 1
  #     arrayExample["numbers"][3].getInt() == 4
  #     arrayExample["names"].len() == 3
  #     arrayExample["names"][0].getStr() == "Alice"
  #     arrayExample["mixed"].len() == 3
  #     arrayExample["mixed"][0].getInt() == 42
  #     arrayExample["mixed"][1].getStr() == "text"
  #     arrayExample["mixed"][2].getBool() == true
  
  # test "Option型のテスト":
  #   let optionExample = %*{
  #     "nickname": csome("Ali"),
  #     "middleName": cnone(),
  #     "rating": csome(5)
  #   }
    
  #   check:
  #     optionExample["nickname"].isSome() == true
  #     optionExample["nickname"].getOpt().getStr() == "Ali"
  #     optionExample["middleName"].isNone() == true
  #     optionExample["rating"].isSome() == true
  #     optionExample["rating"].getOpt().getInt() == 5
  
  # test "Variant型のテスト":
  #   let variantExample = %*{
  #     "status": cvariant("Active"),
  #     "error": cvariant("Error", "Connection failed"),
  #     "result": cvariant("Success", 42)
  #   }
    
  #   check:
  #     variantExample["status"].variantTag() == "Active"
  #     variantExample["status"].variantVal().isNull() == true
  #     variantExample["error"].variantTag() == "Error"
  #     variantExample["error"].variantVal().getStr() == "Connection failed"
  #     variantExample["result"].variantTag() == "Success"
  #     variantExample["result"].variantVal().getInt() == 42
  
  # test "Func型とService型のテスト":
  #   let funcExample = %*{
  #     "callback": cfunc("w7x7r-cok77-xa", "handleRequest"),
  #     "target": cservice("aaaaa-aa")
  #   }
    
  #   check:
  #     funcExample["callback"].funcPrincipal() == "w7x7r-cok77-xa"
  #     funcExample["callback"].funcMethod() == "handleRequest"
  #     funcExample["callback"].isFunc() == true
  #     funcExample["target"].isService() == true
  
  # test "ネストした複雑な構造のテスト":
  #   let complexExample = %*{
  #     "user": {
  #       "id": cprincipal("user-123"),
  #       "profile": {
  #         "name": "Alice",
  #         "age": 30,
  #         "preferences": {
  #           "theme": cvariant("Dark"),
  #           "notifications": csome(true)
  #         }
  #       },
  #       "permissions": ["read", "write"],
  #       "metadata": cblob([0x01, 0x02, 0x03])
  #     },
  #     "system": {
  #       "version": "1.0.0",
  #       "services": [
  #         cservice("service-1"),
  #         cservice("service-2")
  #       ],
  #       "callbacks": [
  #         cfunc("handler-1", "process"),
  #         cfunc("handler-2", "validate")
  #       ]
  #     }
  #   }
    
  #   check:
  #     complexExample["user"]["id"].asPrincipal() == "user-123"
  #     complexExample["user"]["profile"]["name"].getStr() == "Alice"
  #     complexExample["user"]["profile"]["age"].getInt() == 30
  #     complexExample["user"]["profile"]["preferences"]["theme"].variantTag() == "Dark"
  #     complexExample["user"]["profile"]["preferences"]["notifications"].isSome() == true
  #     complexExample["user"]["permissions"].len() == 2
  #     complexExample["user"]["permissions"][0].getStr() == "read"
  #     complexExample["user"]["metadata"].getBytes() == @[0x01u8, 0x02u8, 0x03u8]
  #     complexExample["system"]["version"].getStr() == "1.0.0"
  #     complexExample["system"]["services"].len() == 2
  #     complexExample["system"]["callbacks"].len() == 2
  #     complexExample["system"]["callbacks"][0].funcPrincipal() == "handler-1"
  #     complexExample["system"]["callbacks"][0].funcMethod() == "process"
  
  # test "変数を使った動的構成のテスト":
  #   let userName = "Bob"
  #   let userAge = 25
  #   let isAdmin = true
  #   let userData = @[1u8, 2u8, 3u8]
    
  #   let dynamicExample = %*{
  #     "name": userName,
  #     "age": userAge,
  #     "isAdmin": isAdmin,
  #     "data": userData
  #   }
    
  #   check:
  #     dynamicExample["name"].getStr() == "Bob"
  #     dynamicExample["age"].getInt() == 25
  #     dynamicExample["isAdmin"].getBool() == true
  #     dynamicExample["data"].getBytes() == @[1u8, 2u8, 3u8]
  
  # test "JSON風文字列変換のテスト":
  #   let jsonExample = %*{
  #     "text": "Hello",
  #     "number": 42,
  #     "boolean": true,
  #     "null": cnull(),
  #     "array": [1, 2, 3],
  #     "option": csome("value"),
  #     "variant": cvariant("Tag", "content"),
  #     "principal": cprincipal("aaaaa-aa"),
  #     "func": cfunc("principal", "method"),
  #     "service": cservice("service-id"),
  #     "blob": cblob([0x01, 0x02])
  #   }
    
  #   let jsonStr = $jsonExample
  #   # JSON文字列が生成されることを確認（詳細は省略）
  #   check:
  #     jsonStr.len > 0
  #     strutils.contains(jsonStr, "\"text\"")
  #     strutils.contains(jsonStr, "\"Hello\"")
  #     strutils.contains(jsonStr, "42")
  #     strutils.contains(jsonStr, "true")
  #     strutils.contains(jsonStr, "null")
  #     strutils.contains(jsonStr, "some")
  #     strutils.contains(jsonStr, "Tag")
  #     strutils.contains(jsonStr, "aaaaa-aa")
  #     strutils.contains(jsonStr, "base64")
  
  # test "配列とレコードの操作テスト":
  #   # 空の配列とレコードから開始
  #   var record = newCRecord()
  #   var array = newCArray()
    
  #   # 動的に要素を追加
  #   record["name"] = %*"Alice"
  #   record["scores"] = array
    
  #   array.add(%*90)
  #   array.add(%*85)
  #   array.add(%*88)
    
  #   check:
  #     record["name"].getStr() == "Alice"
  #     record["scores"].len() == 3
  #     record["scores"][0].getInt() == 90
  #     record["scores"][2].getInt() == 88
    
  #   # フィールドの削除
  #   record.delete("name")
  #   check:
  #     not ic_record.contains(record, "name")
    
  #   # 配列要素の削除
  #   array.delete(1)  # 85を削除
  #   check:
  #     array.len() == 2
  #     array[1].getInt() == 88  # 88が2番目になる
  
  # test "型判定ヘルパーのテスト":
  #   let mixedData = %*{
  #     "null": cnull(),
  #     "bool": true,
  #     "int": 42,
  #     "float": 3.14,
  #     "text": "hello",
  #     "blob": cblob([1, 2, 3]),
  #     "array": [1, 2],
  #     "record": {"nested": "value"},
  #     "option": csome("opt"),
  #     "variant": cvariant("Tag"),
  #     "principal": cprincipal("id"),
  #     "func": cfunc("p", "m"),
  #     "service": cservice("s")
  #   }
    
  #   check:
  #     mixedData["null"].isNull()
  #     mixedData["bool"].isBool()
  #     mixedData["int"].isInt()
  #     mixedData["float"].isFloat64()
  #     mixedData["text"].isText()
  #     mixedData["blob"].isBlob()
  #     mixedData["array"].isArray()
  #     mixedData["record"].isRecord()
  #     mixedData["option"].isOption()
  #     mixedData["variant"].isVariant()
  #     mixedData["principal"].isPrincipal()
  #     mixedData["func"].isFunc()
  #     mixedData["service"].isService()
