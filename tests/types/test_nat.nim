discard """
cmd: nim c --skipUserCfg tests/types/test_nat.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat tests":
  test "encode with small nat":
    let natValue = newCandidNat(42u)
    let encoded = encodeCandidMessage(@[natValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト（小さい値の場合）
    check encoded.len == 8


  test "encode with zero":
    let natValue = newCandidNat(0u)
    let encoded = encodeCandidMessage(@[natValue])
    check encoded.len == 8


  test "encode with large nat":
    let natValue = newCandidNat(1000000u)
    let encoded = encodeCandidMessage(@[natValue])
    # 大きな値はより多くのバイトを使用
    check encoded.len > 8


  test "encode and decode with small nat":
    let natValue = newCandidNat(123u)
    let encoded = encodeCandidMessage(@[natValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat
    check decoded.values[0].natVal == 123u


  test "encode and decode with zero":
    let natValue = newCandidNat(0u)
    let encoded = encodeCandidMessage(@[natValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat
    check decoded.values[0].natVal == 0u


  test "encode and decode with large nat":
    let natValue = newCandidNat(4294967295u) # 2^32 - 1
    let encoded = encodeCandidMessage(@[natValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat
    check decoded.values[0].natVal == 4294967295u


  test "multiple nat values":
    let natValue1 = newCandidNat(10u)
    let natValue2 = newCandidNat(20u)
    let natValue3 = newCandidNat(30u)
    let encoded = encodeCandidMessage(@[natValue1, natValue2, natValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat
    check decoded.values[0].natVal == 10u
    check decoded.values[1].kind == ctNat
    check decoded.values[1].natVal == 20u
    check decoded.values[2].kind == ctNat
    check decoded.values[2].natVal == 30u


  test "nat value type check":
    let natValue = newCandidNat(999u)
    check natValue.kind == ctNat
    check natValue.natVal == 999u


suite "ic_nat8 tests":
  test "encode with small nat8":
    let nat8Value = newCandidValue(42u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト
    check encoded.len == 8

  test "encode with zero nat8":
    let nat8Value = newCandidValue(0u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    check encoded.len == 8

  test "encode with max nat8":
    let nat8Value = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    check encoded.len == 8

  test "encode and decode with small nat8":
    let nat8Value = newCandidValue(123u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 123u

  test "encode and decode with zero nat8":
    let nat8Value = newCandidValue(0u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 0u

  test "encode and decode with max nat8":
    let nat8Value = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 255u

  test "multiple nat8 values":
    let nat8Value1 = newCandidValue(10u8)
    let nat8Value2 = newCandidValue(20u8)
    let nat8Value3 = newCandidValue(255u8)
    let encoded = encodeCandidMessage(@[nat8Value1, nat8Value2, nat8Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat8
    check decoded.values[0].natVal == 10u
    check decoded.values[1].kind == ctNat8
    check decoded.values[1].natVal == 20u
    check decoded.values[2].kind == ctNat8
    check decoded.values[2].natVal == 255u

  test "nat8 boundary values":
    # Test boundary values: 0, 1, 254, 255
    let values = [0u8, 1u8, 254u8, 255u8]
    for val in values:
      let nat8Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat8Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat8
      check decoded.values[0].natVal == uint(val)

  test "nat8 value type check":
    let nat8Value = newCandidValue(199u8)
    check nat8Value.kind == ctNat8
    check nat8Value.natVal == 199u


suite "ic_nat16 tests":
  test "encode with nat16 zero":
    let nat16Value = newCandidValue(0'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with nat16 small value":
    let nat16Value = newCandidValue(42'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode with nat16 max value":
    let nat16Value = newCandidValue(65535'u16)  # 2^16 - 1
    let encoded = encodeCandidMessage(@[nat16Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat16値(2バイト) = 9バイト
    check encoded.len == 9

  test "encode and decode with nat16 zero":
    let nat16Value = newCandidValue(0'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat16 small value":
    let nat16Value = newCandidValue(42'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat16 max value":
    let nat16Value = newCandidValue(65535'u16)
    let encoded = encodeCandidMessage(@[nat16Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 65535'u

  test "encode and decode with nat16 boundary values":
    let values = [1'u16, 255'u16, 256'u16, 32767'u16, 32768'u16, 65534'u16]
    for val in values:
      let nat16Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat16Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat16
      check decoded.values[0].natVal == uint(val)

  test "multiple nat16 values":
    let nat16Value1 = newCandidValue(100'u16)
    let nat16Value2 = newCandidValue(200'u16)
    let nat16Value3 = newCandidValue(65535'u16)
    let encoded = encodeCandidMessage(@[nat16Value1, nat16Value2, nat16Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat16
    check decoded.values[0].natVal == 100'u
    check decoded.values[1].kind == ctNat16
    check decoded.values[1].natVal == 200'u
    check decoded.values[2].kind == ctNat16
    check decoded.values[2].natVal == 65535'u

  test "nat16 value properties":
    let nat16Value = newCandidValue(1000'u16)
    check nat16Value.kind == ctNat16
    check nat16Value.natVal == 1000'u


suite "ic_nat32 tests":
  test "encode with nat32 zero":
    let nat32Value = newCandidValue(0'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with nat32 small value":
    let nat32Value = newCandidValue(42'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode with nat32 max value":
    let nat32Value = newCandidValue(4294967295'u32)  # 2^32 - 1
    let encoded = encodeCandidMessage(@[nat32Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat32値(4バイト) = 11バイト
    check encoded.len == 11

  test "encode and decode with nat32 zero":
    let nat32Value = newCandidValue(0'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat32 small value":
    let nat32Value = newCandidValue(42'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat32 max value":
    let nat32Value = newCandidValue(4294967295'u32)
    let encoded = encodeCandidMessage(@[nat32Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 4294967295'u

  test "encode and decode with nat32 boundary values":
    let values = [1'u32, 255'u32, 256'u32, 65535'u32, 65536'u32, 4294967294'u32]
    for val in values:
      let nat32Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat32Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat32
      check decoded.values[0].natVal == uint(val)

  test "multiple nat32 values":
    let nat32Value1 = newCandidValue(100'u32)
    let nat32Value2 = newCandidValue(200'u32)
    let nat32Value3 = newCandidValue(4294967295'u32)
    let encoded = encodeCandidMessage(@[nat32Value1, nat32Value2, nat32Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat32
    check decoded.values[0].natVal == 100'u
    check decoded.values[1].kind == ctNat32
    check decoded.values[1].natVal == 200'u
    check decoded.values[2].kind == ctNat32
    check decoded.values[2].natVal == 4294967295'u

  test "nat32 value properties":
    let nat32Value = newCandidValue(1000'u32)
    check nat32Value.kind == ctNat32
    check nat32Value.natVal == 1000'u


suite "ic_nat64 tests":
  test "encode with nat64 zero":
    let nat64Value = newCandidValue(0'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with nat64 small value":
    let nat64Value = newCandidValue(42'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode with nat64 max value":
    let nat64Value = newCandidValue(18446744073709551615'u64)  # 2^64 - 1
    let encoded = encodeCandidMessage(@[nat64Value])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + nat64値(8バイト) = 15バイト
    check encoded.len == 15

  test "encode and decode with nat64 zero":
    let nat64Value = newCandidValue(0'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 0'u

  test "encode and decode with nat64 small value":
    let nat64Value = newCandidValue(42'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 42'u

  test "encode and decode with nat64 max value":
    let nat64Value = newCandidValue(18446744073709551615'u64)
    let encoded = encodeCandidMessage(@[nat64Value])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 18446744073709551615'u

  test "encode and decode with nat64 boundary values":
    let values = [1'u64, 255'u64, 256'u64, 65535'u64, 65536'u64, 4294967295'u64, 4294967296'u64, 18446744073709551614'u64]
    for val in values:
      let nat64Value = newCandidValue(val)
      let encoded = encodeCandidMessage(@[nat64Value])
      let decoded = decodeCandidMessage(encoded)
      check decoded.values[0].kind == ctNat64
      check decoded.values[0].natVal == uint(val)

  test "multiple nat64 values":
    let nat64Value1 = newCandidValue(1000'u64)
    let nat64Value2 = newCandidValue(2000'u64)
    let nat64Value3 = newCandidValue(18446744073709551615'u64)
    let encoded = encodeCandidMessage(@[nat64Value1, nat64Value2, nat64Value3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctNat64
    check decoded.values[0].natVal == 1000'u
    check decoded.values[1].kind == ctNat64
    check decoded.values[1].natVal == 2000'u
    check decoded.values[2].kind == ctNat64
    check decoded.values[2].natVal == 18446744073709551615'u

  test "nat64 value properties":
    let nat64Value = newCandidValue(10000000000'u64)
    check nat64Value.kind == ctNat64
    check nat64Value.natVal == 10000000000'u 