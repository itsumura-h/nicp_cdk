discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/types/test_vec.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "ic_vec tests":
  test "encode with empty vec":
    let vecValue = newCandidVecEmpty()
    let encoded = encodeCandidMessage(@[vecValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(サイズ可変) + 長さ0(1バイト) = 最小サイズ
    check encoded.len >= 8
    echo "Empty vec encoded size: ", encoded.len, " bytes"

  test "encode with vec of nat8":
    let nat8Values = @[
      newCandidValue(uint8(1)),
      newCandidValue(uint8(2)),
      newCandidValue(uint8(3))
    ]
    let vecValue = newCandidVec(nat8Values)
    let encoded = encodeCandidMessage(@[vecValue])
    # エンコードサイズを検証
    check encoded.len > 8
    echo "Vec of 3 nat8 encoded size: ", encoded.len, " bytes"

  test "encode with vec of nat16":
    let nat16Values = @[
      newCandidValue(uint16(100)),
      newCandidValue(uint16(200)),
      newCandidValue(uint16(300))
    ]
    let vecValue = newCandidVec(nat16Values)
    let encoded = encodeCandidMessage(@[vecValue])
    check encoded.len > 8
    echo "Vec of 3 nat16 encoded size: ", encoded.len, " bytes"

  test "encode with vec of text":
    let textValues = @[
      newCandidText("Hello"),
      newCandidText("World"),
      newCandidText("Test")
    ]
    let vecValue = newCandidVec(textValues)
    let encoded = encodeCandidMessage(@[vecValue])
    check encoded.len > 8
    echo "Vec of 3 text encoded size: ", encoded.len, " bytes"

  test "encode and decode with empty vec":
    let vecValue = newCandidVecEmpty()
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 0

  test "encode and decode with vec of nat8":
    let nat8Values = @[
      newCandidValue(uint8(42)),
      newCandidValue(uint8(100)),
      newCandidValue(uint8(255))
    ]
    let vecValue = newCandidVec(nat8Values)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 3
    # 各要素の値を検証
    check decoded.values[0].vecVal[0].kind == ctNat8
    check decoded.values[0].vecVal[0].nat8Val == 42u
    check decoded.values[0].vecVal[1].kind == ctNat8
    check decoded.values[0].vecVal[1].nat8Val == 100u
    check decoded.values[0].vecVal[2].kind == ctNat8
    check decoded.values[0].vecVal[2].nat8Val == 255u

  test "encode and decode with vec of nat16":
    let nat16Values = @[
      newCandidValue(uint16(1000)),
      newCandidValue(uint16(2000)),
      newCandidValue(uint16(65535))
    ]
    let vecValue = newCandidVec(nat16Values)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 3
    # 各要素の値を検証
    check decoded.values[0].vecVal[0].kind == ctNat16
    check decoded.values[0].vecVal[0].nat16Val == 1000u
    check decoded.values[0].vecVal[1].kind == ctNat16
    check decoded.values[0].vecVal[1].nat16Val == 2000u
    check decoded.values[0].vecVal[2].kind == ctNat16
    check decoded.values[0].vecVal[2].nat16Val == 65535u

  test "encode and decode with vec of text":
    let textValues = @[
      newCandidText("Hello"),
      newCandidText("World"),
      newCandidText("テスト")
    ]
    let vecValue = newCandidVec(textValues)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 3
    # 各要素の値を検証
    check decoded.values[0].vecVal[0].kind == ctText
    check decoded.values[0].vecVal[0].textVal == "Hello"
    check decoded.values[0].vecVal[1].kind == ctText
    check decoded.values[0].vecVal[1].textVal == "World"
    check decoded.values[0].vecVal[2].kind == ctText
    check decoded.values[0].vecVal[2].textVal == "テスト"

  test "encode and decode with vec of bool":
    let boolValues = @[
      newCandidBool(true),
      newCandidBool(false),
      newCandidBool(true)
    ]
    let vecValue = newCandidVec(boolValues)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 3
    # 各要素の値を検証
    check decoded.values[0].vecVal[0].kind == ctBool
    check decoded.values[0].vecVal[0].boolVal == true
    check decoded.values[0].vecVal[1].kind == ctBool
    check decoded.values[0].vecVal[1].boolVal == false
    check decoded.values[0].vecVal[2].kind == ctBool
    check decoded.values[0].vecVal[2].boolVal == true

  test "encode and decode with large vec":
    # 100個の要素を含む大きなベクター
    var nat8Values: seq[CandidValue] = @[]
    for i in 0..<100:
      nat8Values.add(newCandidValue(uint8(i mod 256)))
    let vecValue = newCandidVec(nat8Values)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 100
    # 先頭と末尾の要素を検証
    check decoded.values[0].vecVal[0].kind == ctNat8
    check decoded.values[0].vecVal[0].nat8Val == 0u
    check decoded.values[0].vecVal[99].kind == ctNat8
    check decoded.values[0].vecVal[99].nat8Val == 99u

  test "multiple vec values":
    let vecValue1 = newCandidVec(@[newCandidValue(uint8(1)), newCandidValue(uint8(2))])
    let vecValue2 = newCandidVec(@[newCandidText("A"), newCandidText("B")])
    let vecValue3 = newCandidVec(@[newCandidBool(true), newCandidBool(false)])
    let encoded = encodeCandidMessage(@[vecValue1, vecValue2, vecValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    
    # 最初のベクター（nat8）
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 2
    check decoded.values[0].vecVal[0].nat8Val == 1u
    check decoded.values[0].vecVal[1].nat8Val == 2u
    
    # 2番目のベクター（text）
    check decoded.values[1].kind == ctVec
    check decoded.values[1].vecVal.len == 2
    check decoded.values[1].vecVal[0].textVal == "A"
    check decoded.values[1].vecVal[1].textVal == "B"
    
    # 3番目のベクター（bool）
    check decoded.values[2].kind == ctVec
    check decoded.values[2].vecVal.len == 2
    check decoded.values[2].vecVal[0].boolVal == true
    check decoded.values[2].vecVal[1].boolVal == false

  test "vec value type check":
    let nat8Values = @[
      newCandidValue(uint8(10)),
      newCandidValue(uint8(20)),
      newCandidValue(uint8(30))
    ]
    let vecValue = newCandidVec(nat8Values)
    check vecValue.kind == ctVec
    check vecValue.vecVal.len == 3
    check vecValue.vecVal[0].nat8Val == 10u
    check vecValue.vecVal[1].nat8Val == 20u
    check vecValue.vecVal[2].nat8Val == 30u

  test "vec boundary values nat8":
    # nat8の境界値テスト
    let nat8BoundaryValues = @[
      newCandidValue(uint8(0)),      # 最小値
      newCandidValue(uint8(255))     # 最大値
    ]
    let vecValue = newCandidVec(nat8BoundaryValues)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 2
    # 各境界値を検証
    check decoded.values[0].vecVal[0].kind == ctNat8
    check decoded.values[0].vecVal[0].nat8Val == 0u
    check decoded.values[0].vecVal[1].kind == ctNat8
    check decoded.values[0].vecVal[1].nat8Val == 255u

  test "vec boundary values nat16":
    # nat16の境界値テスト
    let nat16BoundaryValues = @[
      newCandidValue(uint16(0)),     # 最小値
      newCandidValue(uint16(65535))  # 最大値
    ]
    let vecValue = newCandidVec(nat16BoundaryValues)
    let encoded = encodeCandidMessage(@[vecValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVec
    check decoded.values[0].vecVal.len == 2
    # 各境界値を検証
    check decoded.values[0].vecVal[0].kind == ctNat16
    check decoded.values[0].vecVal[0].nat16Val == 0u
    check decoded.values[0].vecVal[1].kind == ctNat16
    check decoded.values[0].vecVal[1].nat16Val == 65535u 