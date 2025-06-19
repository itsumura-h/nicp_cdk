discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_record.nim

import std/unittest
import ../../src/nicp_cdk/ic_types/ic_record


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


