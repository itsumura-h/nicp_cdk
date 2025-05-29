discard """
  cmd:"nim c --skipUserCfg -d:nimOldCaseObjects tests/test_candid.nim"
"""
# nim c -r --skipUserCfg -d:nimOldCaseObjects tests/test_candid.nim

import unittest
include ../src/nicp_cdk/ic_types/candid


proc toBytes*(data: seq[int]): seq[byte] =
  result = newSeq[byte](data.len)
  for i, d in data:
    result[i] = d.byte


suite("Candid parsing tests"):
  test("bool true"):
    const data =  @[68, 73, 68, 76, 0, 1, 126, 1]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctBool
    check args.values[0].boolVal == true

  test("bool false"):
    const data =  @[68, 73, 68, 76, 0, 1, 126, 0]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctBool
    check args.values[0].boolVal == false

  test("nat 1"):
    const data =  @[68, 73, 68, 76, 0, 1, 125, 1]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctNat
    check args.values[0].natVal == 1

  test("nat 1000000000000000000"):
    const data =  @[68, 73, 68, 76, 0, 1, 125, 128, 128, 144, 187, 186, 214, 173, 240, 13]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctNat
    check args.values[0].natVal == 1000000000000000000

  test("int 1"):
    const data =  @[68, 73, 68, 76, 0, 1, 124, 1]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctInt
    check args.values[0].intVal == 1

  test("int -1"):
    const data =  @[68, 73, 68, 76, 0, 1, 124, 127]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctInt
    check args.values[0].intVal == -1

  test("float32 1.0"):
    const data =  @[68, 73, 68, 76, 0, 1, 115, 0, 0, 128, 63]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctFloat32
    check args.values[0].float32Val == 1.0.float32

  test("float32 1.23456"):
    const data =  @[68, 73, 68, 76, 0, 1, 115, 16, 6, 158, 63]
    let bytes = data.toBytes()
    echo "bytes: ", bytes
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctFloat32
    check args.values[0].float32Val == 1.23456.float32

  test("text abc"):
    const data =  @[68, 73, 68, 76, 0, 1, 113, 3, 97, 98, 99]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 1
    check args.values[0].kind == ctText
    check args.values[0].textVal == "abc"

  test("multiple args {bool:true, nat:10, int:20, float32:1.2345, text:abcdef}"):
    const data =  @[68, 73, 68, 76, 0, 5, 126, 125, 124, 115, 113, 1, 10, 20, 25, 4, 158, 63, 6, 97, 98, 99, 100, 101, 102]
    let bytes = data.toBytes()
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args
    check args.values.len == 5
    check args.values[0].kind == ctBool
    check args.values[0].boolVal == true
    check args.values[1].kind == ctNat
    check args.values[1].natVal == 10
    check args.values[2].kind == ctInt
    check args.values[2].intVal == 20
    check args.values[3].kind == ctFloat32
    check args.values[3].float32Val == 1.2345.float32
    check args.values[4].kind == ctText
    check args.values[4].textVal == "abcdef"

  test("t-ecdsa arg record"):
    const data = "4449444c066c03bbebadff0304b3c4b1f20401ada8b2b105026e686d036d7b6c02cbe4fdc70471af99e1f204056b019adee4ea017f01000c6466785f746573745f6b65790000011d1d0859442f591928671ded2612fce56e1d98e3dc7014a284786e945102"
    let bytes = stringToBytes(data)
    echo "bytes: ", bytes
    let args = decodeCandidMessage(bytes)
    echo "args: ", $args