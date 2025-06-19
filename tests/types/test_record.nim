discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_record.nim

import std/unittest
import ../../src/nicp_cdk/ic_types/ic_record

suite("record int"):
  test "record int":
    let record = %*{
      "version": 1
    }
    check record["version"].getInt() == 1

  test "record int8":
    let record = %*{
      "version": 1.int8
    }
    check record["version"].getInt8() == 1.int8

  test "record int16":
    let record = %*{
      "version": 1.int16
    }
    check record["version"].getInt16() == 1.int16

  test "record int32":
    let record = %*{
      "version": 1.int32
    }
    check record["version"].getInt32() == 1.int32

  test "record int64":
    let record = %*{
      "version": 1.int64
    }
    check record["version"].getInt64() == 1.int64


suite("record uint"):
  test "record uint":
    let record = %*{
      "version": 1.uint
    }
    check record["version"].getNat() == 1.uint

  test "record uint8":
    let record = %*{
      "version": 1.uint8
    }
    check record["version"].getNat8() == 1.uint8

  test "record uint16":
    let record = %*{
      "version": 1.uint16
    }
    check record["version"].getNat16() == 1.uint16

  test "record uint32":
    let record = %*{
      "version": 1.uint32
    }
    check record["version"].getNat32() == 1.uint32

  test "record uint64":
    let record = %*{
      "version": 1.uint64
    }
    check record["version"].getNat64() == 1.uint64


suite("record float"):
  test "record float":
    let record = %*{
      "version": 1.23
    }
    check record["version"].getFloat() == 1.23

  test "record float32":
    let record = %*{
      "version": 1.23.float32
    }
    check record["version"].getFloat32() == 1.23.float32

  test "record float64":
    let record = %*{
      "version": 1.23.float64
    }
    check record["version"].getFloat64() == 1.23.float64


suite("record text"):
  test "record text":
    let record = %*{
      "message": "hello"
    }
    check record["message"].getStr() == "hello"
