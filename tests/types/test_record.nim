discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_record.nim

import std/unittest
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_principal


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
    type EcdsaCurve {.pure.} = enum
      secp256k1
      secp256r1
      secp384r1
      secp521r1

    let record = %*{
      "value": EcdsaCurve.secp256k1
    }
    check record["value"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1

  test "record variant - different enum values":
    type EcdsaCurve {.pure.} = enum
      secp256k1
      secp256r1
      secp384r1
      secp521r1

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
    type 
      EcdsaCurve {.pure.} = enum
        secp256k1
        secp256r1
      
      SimpleStatus {.pure.} = enum
        Active
        Inactive

    let record = %*{
      "curve": EcdsaCurve.secp256k1
    }
    
    # 正しい型では成功
    check record["curve"].getVariant(EcdsaCurve) == EcdsaCurve.secp256k1
    
    # 間違った型ではエラー
    expect(ValueError):
      discard record["curve"].getVariant(SimpleStatus)