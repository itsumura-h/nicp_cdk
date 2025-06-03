discard """
  cmd:"nim c --skipUserCfg -d:nimOldCaseObjects tests/test_candid_encode.nim"
"""
# nim c -r --skipUserCfg -d:nimOldCaseObjects tests/test_candid_encode.nim

import unittest
import options
import tables
include ../src/nicp_cdk/ic_types/candid
include ../src/nicp_cdk/ic_types/ic_record
include ../src/nicp_cdk/ic_types/ic_principal

proc toBytes*(data: seq[int]): seq[byte] =
  result = newSeq[byte](data.len)
  for i, d in data:
    result[i] = d.byte


suite("Candid encoding tests"):
  test("bool true"):
    let value = newCandidBool(true)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 126, 1].toBytes()
    check encoded == expected

  test("bool false"):
    let value = newCandidBool(false)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 126, 0].toBytes()
    check encoded == expected

  test("nat 1"):
    let value = newCandidNat(1)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 125, 1].toBytes()
    check encoded == expected

  test("nat 1000000000000000000"):
    let value = newCandidNat(1000000000000000000)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 125, 128, 128, 144, 187, 186, 214, 173, 240, 13].toBytes()
    check encoded == expected

  test("int 1"):
    let value = newCandidInt(1)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 124, 1].toBytes()
    check encoded == expected

  test("int -1"):
    let value = newCandidInt(-1)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 124, 127].toBytes()
    check encoded == expected

  test("float32 1.0"):
    let value = newCandidFloat(1.0)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 115, 0, 0, 128, 63].toBytes()
    check encoded == expected

  test("float32 1.23456"):
    let value = newCandidFloat(1.23456)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 115, 16, 6, 158, 63].toBytes()
    check encoded == expected

  test("text abc"):
    let value = newCandidText("abc")
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 113, 3, 97, 98, 99].toBytes()
    check encoded == expected

  test("principal anonymous"):
    let principal = Principal.fromText("2vxsx-fae")
    let value = newCandidPrincipal(principal)
    let encoded = encodeCandidMessage(@[value])
    let expected = @[68, 73, 68, 76, 0, 1, 104, 1, 1, 4].toBytes()  # DIDL + typeTable(0) + valueCount(1) + type(principal) + IDform(1) + length(1) + principal_bytes(4)
    check encoded == expected

  test("principal management canister"):
    let principal = Principal.fromText("aaaaa-aa")
    let value = newCandidPrincipal(principal)
    let encoded = encodeCandidMessage(@[value])
    echo "Encoded principal management canister: ", encoded.mapIt(it.int)

  test("principal with text identifier"):
    let principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let value = newCandidPrincipal(principal)
    let encoded = encodeCandidMessage(@[value])
    echo "Encoded principal with text identifier: ", encoded.mapIt(it.int)

  test("multiple args {bool:true, nat:10, int:20, float32:1.2345, text:abcdef}"):
    let values = @[
      newCandidBool(true),
      newCandidNat(10),
      newCandidInt(20),
      newCandidFloat(1.2345),
      newCandidText("abcdef")
    ]
    let encoded = encodeCandidMessage(values)
    let expected = @[68, 73, 68, 76, 0, 5, 126, 125, 124, 115, 113, 1, 10, 20, 25, 4, 158, 63, 6, 97, 98, 99, 100, 101, 102].toBytes()
    check encoded == expected

  test("null value"):
    let value = newCandidNull()
    let encoded = encodeCandidMessage(@[value])
    # null型のエンコード結果（値部分は空）
    let expected = @[68, 73, 68, 76, 0, 1, 127].toBytes()  # DIDL + typeTable(0) + valueCount(1) + type(null/-1=0x7F) + (no value)
    check encoded == expected

  test("opt some value"):
    let innerValue = newCandidNat(42)
    let optValue = newCandidOpt(some(innerValue))
    let encoded = encodeCandidMessage(@[optValue])
    echo "Encoded opt some: ", encoded.mapIt(it.int)

  test("opt none value"):
    let optValue = newCandidOpt(none(CandidValue))
    let encoded = encodeCandidMessage(@[optValue])
    echo "Encoded opt none: ", encoded.mapIt(it.int)

  test("vec with nat values"):
    let vecValue = newCandidVec(@[
      newCandidNat(1),
      newCandidNat(2),
      newCandidNat(3)
    ])
    let encoded = encodeCandidMessage(@[vecValue])
    echo "Encoded vec: ", encoded.mapIt(it.int)

  test("record with string fields"):
    let recordValue = %*{
      "name": "Alice",
      "age": 30.Natural
    }
    let encoded = encodeCandidMessage(@[recordValue])
    echo "Encoded record: ", encoded.mapIt(it.int)

  test("variant value"):
    let variantValue = newCandidVariant("success", newCandidText("OK"))
    let encoded = encodeCandidMessage(@[variantValue])
    echo "Encoded variant: ", encoded.mapIt(it.int)

suite("Candid round-trip tests"):
  test("encode-decode round trip bool"):
    let original = newCandidBool(true)
    let encoded = encodeCandidMessage(@[original])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctBool
    check decoded.values[0].boolVal == true

  test("encode-decode round trip nat"):
    let original = newCandidNat(12345)
    let encoded = encodeCandidMessage(@[original])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctNat
    check decoded.values[0].natVal == 12345

  test("encode-decode round trip text"):
    let original = newCandidText("Hello, World!")
    let encoded = encodeCandidMessage(@[original])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctText
    check decoded.values[0].textVal == "Hello, World!"

  test("encode-decode round trip principal"):
    let originalPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")
    let original = newCandidPrincipal(originalPrincipal)
    let encoded = encodeCandidMessage(@[original])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.value == "rrkah-fqaaa-aaaaa-aaaaq-cai"
    check decoded.values[0].principalVal.bytes == originalPrincipal.bytes

  test("encode-decode round trip anonymous principal"):
    let originalPrincipal = Principal.fromText("2vxsx-fae")
    let original = newCandidPrincipal(originalPrincipal)
    let encoded = encodeCandidMessage(@[original])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctPrincipal
    check decoded.values[0].principalVal.value == "2vxsx-fae"
    check decoded.values[0].principalVal.bytes == originalPrincipal.bytes

  test("encode-decode round trip multiple values"):
    let originals = @[
      newCandidBool(false),
      newCandidNat(999),
      newCandidInt(-456),
      newCandidText("test")
    ]
    let encoded = encodeCandidMessage(originals)
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 4
    check decoded.values[0].kind == ctBool
    check decoded.values[0].boolVal == false
    check decoded.values[1].kind == ctNat
    check decoded.values[1].natVal == 999
    check decoded.values[2].kind == ctInt
    check decoded.values[2].intVal == -456
    check decoded.values[3].kind == ctText
    check decoded.values[3].textVal == "test"
