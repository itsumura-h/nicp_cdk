discard """
cmd: nim c --skipUserCfg tests/types/test_nat.nim
"""
# nim c -r --skipUserCfg tests/types/test_nat.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


suite "ic_nat tests":
  test "serializeCandid with small nat":
    let natValue = newCandidNat(42u)
    let encoded = encodeCandidMessage(@[natValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) + 値(1バイト) = 8バイト（小さい値の場合）
    check encoded.len == 8


  test "serializeCandid with zero":
    let natValue = newCandidNat(0u)
    let encoded = encodeCandidMessage(@[natValue])
    check encoded.len == 8


  test "serializeCandid with large nat":
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