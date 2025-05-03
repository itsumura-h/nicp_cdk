discard """
  cmd:"nim c --skipUserCfg -d:nimOldCaseObjects tests/test_candid.nim"
"""

import unittest
include ../src/nim_ic_cdk/ic_types/candid

# nim c -r --skipUserCfg -d:nimOldCaseObjects tests/test_candid.nim


proc toBytes*(data: seq[int]): seq[byte] =
  result = newSeq[byte](data.len)
  for i, d in data:
    result[i] = d.byte


suite("Candid parsing tests"):
  test("bool true"):
    const data =  @[68, 73, 68, 76, 0, 1, 126, 1]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctBool
    check args[0].boolVal == true

  test("bool false"):
    const data =  @[68, 73, 68, 76, 0, 1, 126, 0]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctBool
    check args[0].boolVal == false

  test("nat 1"):
    const data =  @[68, 73, 68, 76, 0, 1, 125, 1]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctNat
    check args[0].natVal == 1

  test("nat 1000000000000000000"):
    const data =  @[68, 73, 68, 76, 0, 1, 125, 128, 128, 144, 187, 186, 214, 173, 240, 13]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctNat
    check args[0].natVal == 1000000000000000000

  test("int 1"):
    const data =  @[68, 73, 68, 76, 0, 1, 124, 1]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctInt
    check args[0].intVal == 1

  test("int -1"):
    const data =  @[68, 73, 68, 76, 0, 1, 124, 127]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctInt
    check args[0].intVal == -1

  test("float32 1.0"):
    const data =  @[68, 73, 68, 76, 0, 1, 115, 0, 0, 128, 63]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctFloat32
    check args[0].float32Val == 1.0.float32

  test("float32 1.23456"):
    const data =  @[68, 73, 68, 76, 0, 1, 115, 16, 6, 158, 63]
    let bytes = data.toBytes()
    echo "bytes: ", bytes
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctFloat32
    check args[0].float32Val == 1.23456.float32

  test("text abc"):
    const data =  @[68, 73, 68, 76, 0, 1, 113, 3, 97, 98, 99]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 1
    check args[0].kind == ctText
    check args[0].textVal == "abc"

  test("multiple args {bool:true, nat:10, int:20, float32:1.2345, text:abcdef}"):
    const data =  @[68, 73, 68, 76, 0, 5, 126, 125, 124, 115, 113, 1, 10, 20, 25, 4, 158, 63, 6, 97, 98, 99, 100, 101, 102]
    let bytes = data.toBytes()
    let args = parseCandidArgs(bytes)
    echo "args: ", args.repr
    check args.len == 5
    check args[0].kind == ctBool
    check args[0].boolVal == true
    check args[1].kind == ctNat
    check args[1].natVal == 10
    check args[2].kind == ctInt
    check args[2].intVal == 20
    check args[3].kind == ctFloat32
    check args[3].float32Val == 1.2345.float32
    check args[4].kind == ctText
    check args[4].textVal == "abcdef"
