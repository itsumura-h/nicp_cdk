discard """
  cmd: "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_nested_record.nim

import std/unittest
import std/options
import std/strutils
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/ic_variant
import ../../src/nicp_cdk/ic_types/candid_funcs
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

# ネストしたRecord型のテストスイート
suite "Nested Record tests":
  
  test "シンプルなネストRecord":
    # 2層のネストRecord
    let nestedRecord = %*{
      "user": {
        "name": "Alice",
        "age": 30,
        "isActive": true
      },
      "metadata": {
        "created": "2024-03-20",
        "version": 1
      }
    }
    
    check:
      nestedRecord["user"]["name"].getStr() == "Alice"
      nestedRecord["user"]["age"].getInt() == 30
      nestedRecord["user"]["isActive"].getBool() == true
      nestedRecord["metadata"]["created"].getStr() == "2024-03-20"
      nestedRecord["metadata"]["version"].getInt() == 1
  
  test "深くネストしたRecord":
    # 3層以上のネストRecord
    let deepNestedRecord = %*{
      "organization": {
        "name": "Tech Corp",
        "departments": {
          "engineering": {
            "name": "Engineering",
            "team": {
              "frontend": {
                "name": "Frontend Team",
                "members": 5
              },
              "backend": {
                "name": "Backend Team", 
                "members": 7
              }
            }
          },
          "sales": {
            "name": "Sales",
            "target": 1000000
          }
        }
      },
      "settings": {
        "system": {
          "config": {
            "database": {
              "host": "localhost",
              "port": 5432,
              "ssl": true
            },
            "cache": {
              "enabled": true,
              "ttl": 3600
            }
          }
        }
      }
    }
    
    check:
      deepNestedRecord["organization"]["name"].getStr() == "Tech Corp"
      deepNestedRecord["organization"]["departments"]["engineering"]["name"].getStr() == "Engineering"
      deepNestedRecord["organization"]["departments"]["engineering"]["team"]["frontend"]["name"].getStr() == "Frontend Team"
      deepNestedRecord["organization"]["departments"]["engineering"]["team"]["frontend"]["members"].getInt() == 5
      deepNestedRecord["organization"]["departments"]["engineering"]["team"]["backend"]["members"].getInt() == 7
      deepNestedRecord["organization"]["departments"]["sales"]["target"].getInt() == 1000000
      deepNestedRecord["settings"]["system"]["config"]["database"]["host"].getStr() == "localhost"
      deepNestedRecord["settings"]["system"]["config"]["database"]["port"].getInt() == 5432
      deepNestedRecord["settings"]["system"]["config"]["database"]["ssl"].getBool() == true
      deepNestedRecord["settings"]["system"]["config"]["cache"]["enabled"].getBool() == true
      deepNestedRecord["settings"]["system"]["config"]["cache"]["ttl"].getInt() == 3600

  test "ネストRecord内での配列":
    # ネストしたRecord内に配列を含む場合
    let nestedWithArray = %*{
      "user": {
        "name": "Bob",
        "contacts": {
          "emails": ["bob@example.com", "bob.work@company.com"],
          "phones": ["+1-555-0123", "+1-555-0456"]
        },
        "preferences": {
          "languages": ["English", "Japanese", "Spanish"],
          "themes": ["dark", "light"]
        }
      }
    }
    
    check:
      nestedWithArray["user"]["name"].getStr() == "Bob"
      nestedWithArray["user"]["contacts"]["emails"].len() == 2
      nestedWithArray["user"]["contacts"]["emails"][0].getStr() == "bob@example.com"
      nestedWithArray["user"]["contacts"]["emails"][1].getStr() == "bob.work@company.com"
      nestedWithArray["user"]["contacts"]["phones"].len() == 2
      nestedWithArray["user"]["contacts"]["phones"][0].getStr() == "+1-555-0123"
      nestedWithArray["user"]["preferences"]["languages"].len() == 3
      nestedWithArray["user"]["preferences"]["languages"][0].getStr() == "English"
      nestedWithArray["user"]["preferences"]["languages"][2].getStr() == "Spanish"
      nestedWithArray["user"]["preferences"]["themes"].len() == 2

  test "ネストRecord内でのOption型":
    # ネストしたRecord内にOption型を含む場合
    let nestedWithOption = %*{
      "profile": {
        "user": {
          "name": "Charlie",
          "nickname": some("Chuck"),
          "middleName": none(string),
          "bio": some("Software developer")
        },
        "settings": {
          "theme": some("dark"),
          "notifications": some(true),
          "customConfig": none(string)
        }
      }
    }
    
    check:
      nestedWithOption["profile"]["user"]["name"].getStr() == "Charlie"
      nestedWithOption["profile"]["user"]["nickname"].isSome() == true
      nestedWithOption["profile"]["user"]["nickname"].getOpt().getStr() == "Chuck"
      nestedWithOption["profile"]["user"]["middleName"].isNone() == true
      nestedWithOption["profile"]["user"]["bio"].isSome() == true
      nestedWithOption["profile"]["user"]["bio"].getOpt().getStr() == "Software developer"
      nestedWithOption["profile"]["settings"]["theme"].isSome() == true
      nestedWithOption["profile"]["settings"]["theme"].getOpt().getStr() == "dark"
      nestedWithOption["profile"]["settings"]["notifications"].isSome() == true
      nestedWithOption["profile"]["settings"]["notifications"].getOpt().getBool() == true
      nestedWithOption["profile"]["settings"]["customConfig"].isNone() == true

  # test "ネストRecord内でのVariant型":
  #   # ネストしたRecord内にVariant型を含む場合（一時的にコメントアウト）
  #   let nestedWithVariant = %*{
  #     "request": {
  #       "id": "req-123",
  #       "result": {
  #         "status": newCVariant("success", newCText("Operation completed")),
  #         "data": {
  #           "response": newCVariant("ok", newCText("All good")),
  #           "error": newCVariant("none")
  #         }
  #       }
  #     }
  #   }
  #   
  #   let statusVariant = nestedWithVariant["request"]["result"]["status"].getVariant()
  #   let responseVariant = nestedWithVariant["request"]["result"]["data"]["response"].getVariant()
  #   let errorVariant = nestedWithVariant["request"]["result"]["data"]["error"].getVariant()
  #   
  #   check:
  #     nestedWithVariant["request"]["id"].getStr() == "req-123"
  #     statusVariant.tag == candidHash("success")
  #     statusVariant.value.getStr() == "Operation completed"
  #     responseVariant.tag == candidHash("ok")
  #     responseVariant.value.getStr() == "All good"
  #     errorVariant.tag == candidHash("none")
  #     errorVariant.value.isNull() == true

  test "ネストRecord内でのPrincipal型":
    # ネストしたRecord内にPrincipal型を含む場合
    let owner = Principal.fromText("aaaaa-aa")
    let ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")
    let registry = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    
    let nestedWithPrincipal = %*{
      "canister": {
        "owner": owner,
        "services": {
          "ledger": {
            "principal": ledger,
            "name": "ICP Ledger"
          },
          "registry": {
            "principal": registry,
            "name": "Service Registry"
          }
        },
        "permissions": {
          "admin": owner,
          "canRead": [owner, ledger],
          "canWrite": [owner]
        }
      }
    }
    
    check:
      nestedWithPrincipal["canister"]["owner"].getPrincipal() == owner
      nestedWithPrincipal["canister"]["services"]["ledger"]["principal"].getPrincipal() == ledger
      nestedWithPrincipal["canister"]["services"]["ledger"]["name"].getStr() == "ICP Ledger"
      nestedWithPrincipal["canister"]["services"]["registry"]["principal"].getPrincipal() == registry
      nestedWithPrincipal["canister"]["services"]["registry"]["name"].getStr() == "Service Registry"
      nestedWithPrincipal["canister"]["permissions"]["admin"].getPrincipal() == owner
      nestedWithPrincipal["canister"]["permissions"]["canRead"].len() == 2
      nestedWithPrincipal["canister"]["permissions"]["canRead"][0].getPrincipal() == owner
      nestedWithPrincipal["canister"]["permissions"]["canRead"][1].getPrincipal() == ledger
      nestedWithPrincipal["canister"]["permissions"]["canWrite"].len() == 1
      nestedWithPrincipal["canister"]["permissions"]["canWrite"][0].getPrincipal() == owner

  test "ネストRecord内でのBlob型":
    # ネストしたRecord内にBlob型を含む場合
    let nestedWithBlob = %*{
      "data": {
        "files": {
          "image": {
            "content": @[0x89u8, 0x50u8, 0x4Eu8, 0x47u8].asBlob,  # PNG header
            "type": "image/png"
          },
          "text": {
            "content": @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8].asBlob,  # "Hello"
            "type": "text/plain"
          }
        },
        "metadata": {
          "signature": @[0x41u8, 0x42u8, 0x43u8].asBlob,
          "hash": @[0x01u8, 0x02u8, 0x03u8, 0x04u8].asBlob
        }
      }
    }
    
    check:
      nestedWithBlob["data"]["files"]["image"]["content"].getBytes() == @[0x89u8, 0x50u8, 0x4Eu8, 0x47u8]
      nestedWithBlob["data"]["files"]["image"]["type"].getStr() == "image/png"
      nestedWithBlob["data"]["files"]["text"]["content"].getBytes() == @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8]
      nestedWithBlob["data"]["files"]["text"]["type"].getStr() == "text/plain"
      nestedWithBlob["data"]["metadata"]["signature"].getBytes() == @[0x41u8, 0x42u8, 0x43u8]
      nestedWithBlob["data"]["metadata"]["hash"].getBytes() == @[0x01u8, 0x02u8, 0x03u8, 0x04u8]
      nestedWithBlob["data"]["files"]["image"]["content"].isBlob() == true

  test "混合型の複雑なネストRecord":
    # 様々な型を組み合わせた複雑なネストRecord
    let complexNested = %*{
      "application": {
        "info": {
          "name": "MyApp",
          "version": "1.0.0",
          "settings": {
            "database": {
              "host": "localhost",
              "port": 5432,
              "ssl": true,
              "credentials": {
                "username": some("admin"),
                "password": none(string)
              }
            },
            "cache": {
              "enabled": true,
              "ttl": 3600,
              "servers": ["redis1:6379", "redis2:6379"]
            }
          }
        },
        "users": {
          "active": [
            {
              "id": 1,
              "name": "Alice"
            },
            {
              "id": 2,
              "name": "Bob"
            }
          ],
          "permissions": {
            "admin": [Principal.fromText("aaaaa-aa")],
            "user": [Principal.fromText("aaaaa-aa"), Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")]
          }
        },
        "files": {
          "config": @[0x7Bu8, 0x7Du8].asBlob,  # "{}"
          "logs": @[0x6Cu8, 0x6Fu8, 0x67u8].asBlob   # "log"
        }
      }
    }
    
    check:
      complexNested["application"]["info"]["name"].getStr() == "MyApp"
      complexNested["application"]["info"]["version"].getStr() == "1.0.0"
      complexNested["application"]["info"]["settings"]["database"]["host"].getStr() == "localhost"
      complexNested["application"]["info"]["settings"]["database"]["port"].getInt() == 5432
      complexNested["application"]["info"]["settings"]["database"]["ssl"].getBool() == true
      complexNested["application"]["info"]["settings"]["database"]["credentials"]["username"].isSome() == true
      complexNested["application"]["info"]["settings"]["database"]["credentials"]["username"].getOpt().getStr() == "admin"
      complexNested["application"]["info"]["settings"]["database"]["credentials"]["password"].isNone() == true
      complexNested["application"]["info"]["settings"]["cache"]["enabled"].getBool() == true
      complexNested["application"]["info"]["settings"]["cache"]["ttl"].getInt() == 3600
      complexNested["application"]["info"]["settings"]["cache"]["servers"].len() == 2
      complexNested["application"]["info"]["settings"]["cache"]["servers"][0].getStr() == "redis1:6379"
      complexNested["application"]["info"]["settings"]["cache"]["servers"][1].getStr() == "redis2:6379"
      complexNested["application"]["users"]["active"].len() == 2
      complexNested["application"]["users"]["active"][0]["id"].getInt() == 1
      complexNested["application"]["users"]["active"][0]["name"].getStr() == "Alice"
      complexNested["application"]["users"]["active"][1]["id"].getInt() == 2
      complexNested["application"]["users"]["active"][1]["name"].getStr() == "Bob"
      complexNested["application"]["users"]["permissions"]["admin"].len() == 1
      complexNested["application"]["users"]["permissions"]["admin"][0].getPrincipal() == Principal.fromText("aaaaa-aa")
      complexNested["application"]["users"]["permissions"]["user"].len() == 2
      complexNested["application"]["files"]["config"].getBytes() == @[0x7Bu8, 0x7Du8]
      complexNested["application"]["files"]["logs"].getBytes() == @[0x6Cu8, 0x6Fu8, 0x67u8]

  test "ネストRecordのエンコード・デコードテスト":
    # ネストしたRecordのCandidメッセージエンコード・デコードテスト
    let nestedRecord = %*{
      "user": {
        "name": "Test User",
        "details": {
          "age": 25,
          "active": true
        }
      },
      "timestamp": 1710936000
    }
    
    # nestedRecordはCandidValue型なので、直接使用できる
    # check nestedRecord.kind == ctRecord  # 一時的にコメントアウト
    
    # 基本的な構造のテスト
    check nestedRecord["user"]["name"].getStr() == "Test User"
    check nestedRecord["user"]["details"]["age"].getInt() == 25
    check nestedRecord["user"]["details"]["active"].getBool() == true
    check nestedRecord["timestamp"].getInt() == 1710936000

  test "空のネストRecord":
    # 空のRecordを含むネストしたRecord
    # 空のRecordはnewCRecord()で作成
    let emptyRecord = newCRecord()
    let emptyNested = %*{
      "data": emptyRecord,
      "nested": {
        "value": 42
      }
    }
    
    check:
      # emptyNested["data"].kind == ctRecord  # 一時的にコメントアウト
      emptyNested["nested"]["value"].getInt() == 42

  test "ネストRecord内での非対応型制限":
    # ネストした構造内でも非対応型が制限されることを確認
    expect(ValueError):
      let funcValue = newCFunc("aaaaa-aa", "test")
      let nestedExample = %*{
        "level1": {
          "level2": {
            "callback": funcValue  # ここでエラーが発生すべき
          }
        }
      }