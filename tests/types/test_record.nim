discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_record.nim

import std/unittest
import std/options
import ../../src/nicp_cdk/request
import ../../src/nicp_cdk/reply
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_text
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


type EcdsaCurve {.pure.} = enum
  secp256k1
  secp256r1


suite("record null"):
  test "record null":
    let record = %*{
      "value": nil
    }
    check record["value"].isNull() == true


suite("record bool"):
  test "record true":
    let record = %*{
      "value": true
    }
    check record["value"].getBool() == true

  test "record false":
    let record = %*{
      "value": false
    }
    check record["value"].getBool() == false


suite("record int"):
  test "record int":
    let record = %*{
      "value": 1
    }
    check record["value"].getInt() == 1

  test "record int8":
    let record = %*{
      "value": 1.int8
    }
    check record["value"].getInt8() == 1.int8

  test "record int16":
    let record = %*{
      "value": 1.int16
    }
    check record["value"].getInt16() == 1.int16

  test "record int32":
    let record = %*{
      "value": 1.int32
    }
    check record["value"].getInt32() == 1.int32

  test "record int64":
    let record = %*{
      "value": 1.int64
    }
    check record["value"].getInt64() == 1.int64


suite("record uint"):
  test "record uint":
    let record = %*{
      "value": 1.uint
    }
    check record["value"].getNat() == 1.uint

  test "record uint8":
    let record = %*{
      "value": 1.uint8
    }
    check record["value"].getNat8() == 1.uint8

  test "record uint16":
    let record = %*{
      "value": 1.uint16
    }
    check record["value"].getNat16() == 1.uint16

  test "record uint32":
    let record = %*{
      "value": 1.uint32
    }
    check record["value"].getNat32() == 1.uint32

  test "record uint64":
    let record = %*{
      "value": 1.uint64
    }
    check record["value"].getNat64() == 1.uint64


suite("record float"):
  test "record float":
    let record = %*{
      "value": 1.23
    }
    check record["value"].getFloat() == 1.23

  test "record float32":
    let record = %*{
      "value": 1.23.float32
    }
    check record["value"].getFloat32() == 1.23.float32

  test "record float64":
    let record = %*{
      "value": 1.23.float64
    }
    check record["value"].getFloat64() == 1.23.float64


suite("record text"):
  test "record text":
    let record = %*{
      "value": "hello"
    }
    check record["value"].getStr() == "hello"


suite("record principal"):
  test "record managementCanister 1":
    let record = %*{
      "value": Principal.managementCanister()
    }
    check record["value"].getPrincipal() == Principal.managementCanister()

  test "record managementCanister 2":
    let p = Principal.managementCanister()
    let record = %*{
      "value": p
    }
    check record["value"].getPrincipal() == p


suite("record blob"):
  test "record blob":
    let record = %*{
      "value": @[1'u8, 2'u8, 3'u8].asBlob()
    }
    check record["value"].getBlob() == @[1'u8, 2'u8, 3'u8]

  test "record blob 2":
    let b:seq[uint8] = @[1, 2, 3]
    let record = %*{
      "value": b.asBlob()
    }
    check record["value"].getBlob() == b


suite("record variant"):
  test "record variant":
    let record = %*{
      "value": EcdsaCurve.secp256k1
    }
    check record["value"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1

  test "record variant - different enum values":
    # 各Enum値をテスト
    for curve in EcdsaCurve:
      let record = %*{
        "curve": curve
      }
      check record["curve"].getVariant(EcdsaCurve) == curve

  test "record variant - multiple enum types":
    type 
      EcdsaCurve {.pure.} = enum
        secp256k1
        secp256r1
      
      SimpleStatus {.pure.} = enum
        Active
        Inactive

    let record = %*{
      "curve": EcdsaCurve.secp256r1,
      "status": SimpleStatus.Active
    }
    
    check record["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256r1
    check record["status"].getVariant(SimpleStatus) == SimpleStatus.Active

  test "record variant - type mismatch error":
    let record = %*{
      "curve": EcdsaCurve.secp256k1
    }
    
    # 正しい型では成功
    check record["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1

    # 間違った型ではエラー
    type SimpleStatus {.pure.} = enum
      Active
      Inactive

    expect(ValueError):
      discard record["curve"].getVariant(SimpleStatus)


suite("record option"):
  test "record option some":
    let record = %*{
      "value": some(1)
    }
    check record["value"].isSome() == true
    check record["value"].getOpt().getInt() == 1

  test "record option none":
    let record = %*{
      "value": none(int)
    }
    check record["value"].isNone() == true


suite("record array"):
  test "record seq":
    let record = %*{
      "value": @[1, 2, 3]
    }
    check record["value"].getArray().len == 3
    check record["value"].getArray()[0].getInt() == 1
    check record["value"].getArray()[1].getInt() == 2
    check record["value"].getArray()[2].getInt() == 3

  test("seq empty"):
    let emptySeq: seq[int] = @[]
    let record = %*{
      "value": emptySeq
    }
    check record["value"].getArray().len == 0


  test("record array"):
    let record = %*{
      "value": [1, 2, 3]
    }
    check record["value"].getArray().len == 3
    check record["value"].getArray()[0].getInt() == 1
    check record["value"].getArray()[1].getInt() == 2
    check record["value"].getArray()[2].getInt() == 3


suite("ecdsa arg"):
  test("public key"):
    let arg = %*{
      "canister_id": Principal.managementCanister().some(),
      "derivation_path": @[Principal.governanceCanister().bytes],
      "key_id": {
        "curve": EcdsaCurve.secp256k1,
        "name": "dfx_test_key"
      }
    }
    echo arg
    check arg["canister_id"].getOpt().getPrincipal() == Principal.managementCanister()
    check arg["derivation_path"].getArray().len == 1
    check arg["derivation_path"][0].getBlob() == Principal.governanceCanister().bytes
    check arg["key_id"]["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1
    check arg["key_id"]["name"].getStr() == "dfx_test_key"

  test("sign"):
    let arg = %*{
      "message_hash": "hello".toBlob(),
      "derivation_path": @[Principal.governanceCanister().bytes],
      "key_id": {
        "curve": EcdsaCurve.secp256k1,
        "name": "dfx_test_key"
      }
    }
    echo arg
    let candidRecord = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidRecord])
    echo "encoded: ", encoded.toString()
    let decoded = decodeCandidMessage(encoded)
    let request = newMockRequest(decoded.values)
    check request.getRecord(0)["message_hash"].getBlob() == "hello".toBlob()
    check request.getRecord(0)["derivation_path"].getArray().len == 1


suite("encode, decode"):
  test("encode, decode int"):
    let record = %*{
      "value": 1
    }
    let candidRecord = newCandidRecord(record)
    let encoded = encodeCandidMessage(@[candidRecord])
    let decoded = decodeCandidMessage(encoded)
    let request = newMockRequest(decoded.values)
    check request.getRecord(0)["value"].getInt() == 1

  test("encode, decode ecdsa public key"):
    let arg = %*{
      "canister_id": Principal.managementCanister().some(),
      "derivation_path": @[Principal.governanceCanister().bytes],
      "key_id": {
        "curve": EcdsaCurve.secp256k1,
        "name": "dfx_test_key"
      }
    }
    let candidRecord = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidRecord])
    echo "encoded: ", encoded.toString()
    let decoded = decodeCandidMessage(encoded)
    let request = newMockRequest(decoded.values)
    check request.getRecord(0)["canister_id"].getOpt().getPrincipal() == Principal.managementCanister()
    check request.getRecord(0)["derivation_path"].getArray().len == 1
    check request.getRecord(0)["derivation_path"][0].getBlob() == Principal.governanceCanister().bytes
    check request.getRecord(0)["key_id"]["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1
    check request.getRecord(0)["key_id"]["name"].getStr() == "dfx_test_key"

  test("encode, decode ecdsa signature"):
    let arg = %*{
      "message_hash": "hello".toBlob(),
      "derivation_path": @[Principal.governanceCanister().bytes],
      "key_id": {
        "curve": EcdsaCurve.secp256k1,
        "name": "dfx_test_key"
      }
    }
    let candidRecord = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidRecord])
    echo "encoded: ", encoded.toString()
    let decoded = decodeCandidMessage(encoded)
    let request = newMockRequest(decoded.values)
    check request.getRecord(0)["message_hash"].getBlob() == "hello".toBlob()
    check request.getRecord(0)["derivation_path"].getArray().len == 1
    check request.getRecord(0)["derivation_path"][0].getBlob() == Principal.governanceCanister().bytes
    check request.getRecord(0)["key_id"]["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1
    check request.getRecord(0)["key_id"]["name"].getStr() == "dfx_test_key"
