discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_enum_basic.nim

import unittest
import std/options
import std/strutils
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

# ================================================================================
# テスト用のEnum型定義
# ================================================================================

type
  SimpleStatus {.pure.} = enum
    Active = 0
    Inactive = 1

  Priority {.pure.} = enum
    Low = 0
    Medium = 1
    High = 2
    Critical = 3

  EcdsaCurve {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

# ================================================================================
# Phase 1.1: 基本的なEnum→Variant変換テスト
# ================================================================================

suite "Enum basic conversion tests":
  
  test "SimpleStatus enum to CandidValue conversion":
    # Active値の変換
    let activeValue = newCandidValue(SimpleStatus.Active)
    check activeValue.kind == ctVariant
    check activeValue.variantVal.tag == candidHash("Active")
    check activeValue.variantVal.value.kind == ctNull
    
    # Inactive値の変換
    let inactiveValue = newCandidValue(SimpleStatus.Inactive)
    check inactiveValue.kind == ctVariant
    check inactiveValue.variantVal.tag == candidHash("Inactive")
    check inactiveValue.variantVal.value.kind == ctNull

  test "Priority enum to CandidValue conversion":
    # 4つの値すべてをテスト
    let lowValue = newCandidValue(Priority.Low)
    check lowValue.kind == ctVariant
    check lowValue.variantVal.tag == candidHash("Low")
    
    let mediumValue = newCandidValue(Priority.Medium)
    check mediumValue.kind == ctVariant
    check mediumValue.variantVal.tag == candidHash("Medium")
    
    let highValue = newCandidValue(Priority.High)
    check highValue.kind == ctVariant
    check highValue.variantVal.tag == candidHash("High")
    
    let criticalValue = newCandidValue(Priority.Critical)
    check criticalValue.kind == ctVariant
    check criticalValue.variantVal.tag == candidHash("Critical")

  test "EcdsaCurve enum for Management Canister":
    # secp256k1
    let secp256k1Value = newCandidValue(EcdsaCurve.secp256k1)
    check secp256k1Value.kind == ctVariant
    check secp256k1Value.variantVal.tag == candidHash("secp256k1")
    
    # secp256r1
    let secp256r1Value = newCandidValue(EcdsaCurve.secp256r1)
    check secp256r1Value.kind == ctVariant
    check secp256r1Value.variantVal.tag == candidHash("secp256r1")

# ================================================================================
# Phase 1.2: Variant→Enum変換テスト
# ================================================================================

suite "Variant to Enum conversion tests":

  test "CandidValue to SimpleStatus conversion":
    # Active Variantから変換
    let activeVariant = newCandidVariant("Active", newCandidNull())
    let activeEnum = getEnumValue(activeVariant, SimpleStatus)
    check activeEnum == SimpleStatus.Active
    
    # Inactive Variantから変換
    let inactiveVariant = newCandidVariant("Inactive", newCandidNull())
    let inactiveEnum = getEnumValue(inactiveVariant, SimpleStatus)
    check inactiveEnum == SimpleStatus.Inactive

  test "CandidValue to Priority conversion":
    # 全ての値をテスト
    let lowVariant = newCandidVariant("Low", newCandidNull())
    check getEnumValue(lowVariant, Priority) == Priority.Low
    
    let mediumVariant = newCandidVariant("Medium", newCandidNull())
    check getEnumValue(mediumVariant, Priority) == Priority.Medium
    
    let highVariant = newCandidVariant("High", newCandidNull())
    check getEnumValue(highVariant, Priority) == Priority.High
    
    let criticalVariant = newCandidVariant("Critical", newCandidNull())
    check getEnumValue(criticalVariant, Priority) == Priority.Critical

# ================================================================================
# Phase 1.3: 往復変換テスト
# ================================================================================

suite "Round-trip conversion tests":

  test "SimpleStatus round-trip conversion":
    # Active: Enum → Variant → Enum
    let originalActive = SimpleStatus.Active
    let variantActive = newCandidValue(originalActive)
    let convertedActive = getEnumValue(variantActive, SimpleStatus)
    check convertedActive == originalActive
    
    # Inactive: Enum → Variant → Enum
    let originalInactive = SimpleStatus.Inactive
    let variantInactive = newCandidValue(originalInactive)
    let convertedInactive = getEnumValue(variantInactive, SimpleStatus)
    check convertedInactive == originalInactive

  test "Priority round-trip conversion":
    # 全ての値で往復変換テスト
    for priority in Priority:
      let variant = newCandidValue(priority)
      let converted = getEnumValue(variant, Priority)
      check converted == priority

  test "EcdsaCurve round-trip conversion":
    # Management Canister用の往復変換
    for curve in EcdsaCurve:
      let variant = newCandidValue(curve)
      let converted = getEnumValue(variant, EcdsaCurve)
      check converted == curve

# ================================================================================
# Phase 1.4: エンコード・デコードテスト
# ================================================================================

suite "Enum encode/decode tests":

  test "SimpleStatus encode and decode":
    # Active値のエンコード・デコード
    let activeValue = newCandidValue(SimpleStatus.Active)
    let encoded = encodeCandidMessage(@[activeValue])
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVariant
    let decodedEnum = getEnumValue(decoded.values[0], SimpleStatus)
    check decodedEnum == SimpleStatus.Active

  test "Priority encode and decode":
    # 複数のEnum値をエンコード・デコード
    let values = @[
      newCandidValue(Priority.Low),
      newCandidValue(Priority.High),
      newCandidValue(Priority.Critical)
    ]
    let encoded = encodeCandidMessage(values)
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 3
    check getEnumValue(decoded.values[0], Priority) == Priority.Low
    check getEnumValue(decoded.values[1], Priority) == Priority.High
    check getEnumValue(decoded.values[2], Priority) == Priority.Critical

  test "Mixed enum values encode/decode":
    # 異なるEnum型の混在テスト
    let values = @[
      newCandidValue(SimpleStatus.Active),
      newCandidValue(Priority.Medium),
      newCandidValue(EcdsaCurve.secp256k1)
    ]
    let encoded = encodeCandidMessage(values)
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 3
    check getEnumValue(decoded.values[0], SimpleStatus) == SimpleStatus.Active
    check getEnumValue(decoded.values[1], Priority) == Priority.Medium
    check getEnumValue(decoded.values[2], EcdsaCurve) == EcdsaCurve.secp256k1

# ================================================================================
# Phase 1.5: エラーハンドリングテスト
# ================================================================================

suite "Enum error handling tests":

  test "Invalid variant to enum conversion":
    # 存在しないVariantタグでの変換エラー
    let invalidVariant = newCandidVariant("NonexistentValue", newCandidNull())
    
    expect(ValueError):
      discard getEnumValue(invalidVariant, SimpleStatus)

  test "Non-variant CandidValue to enum conversion":
    # Variant以外のCandidValueでの変換エラー
    let textValue = newCandidText("Active")
    
    expect(ValueError):
      discard getEnumValue(textValue, SimpleStatus)

  test "Enum type validation":
    # Enum型の妥当性チェック
    check isEnumCompatible(SimpleStatus)
    check isEnumCompatible(Priority)
    check isEnumCompatible(EcdsaCurve)

# ================================================================================
# Phase 1.6: 型安全性テスト
# ================================================================================

suite "Enum type safety tests":

  test "Type mismatch detection":
    # 異なるEnum型での変換エラー
    let priorityVariant = newCandidValue(Priority.High)
    
    # Priority VariantをSimpleStatusとして解釈しようとする
    expect(ValueError):
      discard getEnumValue(priorityVariant, SimpleStatus)

  test "Enum string representation consistency":
    # Enum値の文字列表現が一貫していることを確認
    check $SimpleStatus.Active == "Active"
    check $SimpleStatus.Inactive == "Inactive"
    check $Priority.Low == "Low"
    check $Priority.Medium == "Medium"
    check $Priority.High == "High"
    check $Priority.Critical == "Critical"
    check $EcdsaCurve.secp256k1 == "secp256k1"
    check $EcdsaCurve.secp256r1 == "secp256r1"

# ================================================================================
# Phase 1.7: パフォーマンステスト
# ================================================================================

suite "Enum performance tests":

  test "Large number of enum conversions":
    # 大量のEnum変換の性能テスト
    let iterations = 1000
    var conversions: seq[CandidValue] = @[]
    
    for i in 0..<iterations:
      let priority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      conversions.add(newCandidValue(priority))
    
    # 全て正しく変換されていることを確認
    check conversions.len == iterations
    for i, variant in conversions:
      let expectedPriority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      check getEnumValue(variant, Priority) == expectedPriority 