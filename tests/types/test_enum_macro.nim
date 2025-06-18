discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipConfig tests/types/test_enum_macro.nim

import unittest
import std/options
import std/tables
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/ic_record

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
# Phase 2.4: %*マクロでのEnum自動変換テスト
# ================================================================================

suite "%* macro with Enum automatic conversion tests":

  test "Simple enum value conversion":
    # Enum値を%*マクロで自動変換
    let statusRecord = %*SimpleStatus.Active
    check statusRecord.kind == ckVariant
    
    let priorityRecord = %*Priority.High
    check priorityRecord.kind == ckVariant
    
    let curveRecord = %*EcdsaCurve.secp256k1
    check curveRecord.kind == ckVariant

  test "Enum values in record construction":
    # Record内でのEnum自動変換
    let taskRecord = %*{
      "status": SimpleStatus.Active,
      "priority": Priority.High,
      "id": 12345,
      "name": "test_task"
    }
    
    check taskRecord.kind == ckRecord
    check taskRecord.contains("status")
    check taskRecord.contains("priority")
    check taskRecord.contains("id")
    check taskRecord.contains("name")
    
    # Enum値の取得確認
    let status = taskRecord.getEnum(SimpleStatus, "status")
    let priority = taskRecord.getEnum(Priority, "priority")
    
    check status == SimpleStatus.Active
    check priority == Priority.High

  test "Complex record with multiple enum types":
    # 複数のEnum型を含む複雑なRecord
    let complexRecord = %*{
      "user_status": SimpleStatus.Inactive,
      "task_priority": Priority.Critical,
      "crypto_curve": EcdsaCurve.secp256r1,
      "metadata": {
        "created_at": "2024-01-01",
        "updated_status": SimpleStatus.Active
      },
      "settings": {
        "default_priority": Priority.Medium,
        "preferred_curve": EcdsaCurve.secp256k1
      }
    }
    
    check complexRecord.kind == ckRecord
    
    # トップレベルのEnum値確認
    check complexRecord.getEnum(SimpleStatus, "user_status") == SimpleStatus.Inactive
    check complexRecord.getEnum(Priority, "task_priority") == Priority.Critical
    check complexRecord.getEnum(EcdsaCurve, "crypto_curve") == EcdsaCurve.secp256r1
    
    # ネストしたRecord内のEnum値確認
    let metadata = complexRecord["metadata"]
    check metadata.getEnum(SimpleStatus, "updated_status") == SimpleStatus.Active
    
    let settings = complexRecord["settings"]
    check settings.getEnum(Priority, "default_priority") == Priority.Medium
    check settings.getEnum(EcdsaCurve, "preferred_curve") == EcdsaCurve.secp256k1

  test "Array containing enum values":
    # Enum値を含む配列
    let enumArray = %*[
      SimpleStatus.Active,
      SimpleStatus.Inactive,
      SimpleStatus.Active
    ]
    
    check enumArray.kind == ckArray
    check enumArray.len == 3
    
    # 各要素がVariantとして正しく変換されていることを確認
    for i in 0..<enumArray.len:
      let element = enumArray[i]
      check element.kind == ckVariant

  test "Mixed type array with enums":
    # Enum型と他の型を混在させた配列
    let mixedArray = %*[
      "text_value",
      42,
      Priority.High,
      true,
      SimpleStatus.Active
    ]
    
    check mixedArray.kind == ckArray
    check mixedArray.len == 5
    
    # 型チェック
    check mixedArray[0].kind == ckText
    check mixedArray[1].kind == ckInt
    check mixedArray[2].kind == ckVariant  # Priority.High
    check mixedArray[3].kind == ckBool
    check mixedArray[4].kind == ckVariant  # SimpleStatus.Active

# ================================================================================
# Phase 2.5: %*マクロのエラーハンドリングテスト
# ================================================================================

suite "%* macro error handling tests":

  test "Enum conversion consistency":
    # 同じEnum値の変換が一貫していることを確認
    let status1 = %*SimpleStatus.Active
    let status2 = %*SimpleStatus.Active
    
    # 両方ともVariant型であることを確認
    check status1.kind == ckVariant
    check status2.kind == ckVariant
    
    # VariantValueの比較（内部構造が同じかチェック）
    let variant1 = status1.getVariant()
    let variant2 = status2.getVariant()
    check variant1.tag == variant2.tag

  test "Different enum types distinction":
    # 異なるEnum型が正しく区別されることを確認
    let status = %*SimpleStatus.Active
    let priority = %*Priority.Low
    
    check status.kind == ckVariant
    check priority.kind == ckVariant
    
    let statusVariant = status.getVariant()
    let priorityVariant = priority.getVariant()
    
    # 異なるEnum型は異なるハッシュ値を持つ
    check statusVariant.tag != priorityVariant.tag

# ================================================================================
# Phase 2.6: %*マクロの実用的なユースケーステスト
# ================================================================================

suite "%* macro practical use cases":

  test "Management Canister ECDSA key configuration":
    # Management CanisterのECDSA設定シナリオ
    let ecdsaConfig = %*{
      "key_id": {
        "curve": EcdsaCurve.secp256k1,
        "name": "test_key"
      },
      "derivation_path": [],
      "canister_id": "rrkah-fqaaa-aaaaa-aaaaq-cai"
    }
    
    check ecdsaConfig.kind == ckRecord
    
    let keyId = ecdsaConfig["key_id"]
    check keyId.getEnum(EcdsaCurve, "curve") == EcdsaCurve.secp256k1
    check keyId["name"].getStr() == "test_key"

  test "Task management system":
    # タスク管理システムのシナリオ
    let taskList = %*[
      {
        "id": 1,
        "title": "Critical Bug Fix",
        "status": SimpleStatus.Active,
        "priority": Priority.Critical
      },
      {
        "id": 2,
        "title": "Feature Enhancement",
        "status": SimpleStatus.Inactive,
        "priority": Priority.Low
      },
      {
        "id": 3,
        "title": "Security Update",
        "status": SimpleStatus.Active,
        "priority": Priority.High
      }
    ]
    
    check taskList.kind == ckArray
    check taskList.len == 3
    
    # 各タスクのEnum値確認
    let task1 = taskList[0]
    check task1.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    check task1.getEnum(Priority, "priority") == Priority.Critical
    
    let task2 = taskList[1]
    check task2.getEnum(SimpleStatus, "status") == SimpleStatus.Inactive
    check task2.getEnum(Priority, "priority") == Priority.Low

  test "Configuration settings with defaults":
    # デフォルト値を含む設定システム
    let appConfig = %*{
      "user_preferences": {
        "theme": "dark",
        "notification_priority": Priority.Medium,
        "status_visibility": SimpleStatus.Active
      },
      "security_settings": {
        "encryption_curve": EcdsaCurve.secp256r1,
        "auth_status": SimpleStatus.Active,
        "session_priority": Priority.High
      },
      "defaults": {
        "new_task_status": SimpleStatus.Inactive,
        "default_priority": Priority.Low,
        "fallback_curve": EcdsaCurve.secp256k1
      }
    }
    
    check appConfig.kind == ckRecord
    
    # 各セクションのEnum値確認
    let userPrefs = appConfig["user_preferences"]
    check userPrefs.getEnum(Priority, "notification_priority") == Priority.Medium
    check userPrefs.getEnum(SimpleStatus, "status_visibility") == SimpleStatus.Active
    
    let securitySettings = appConfig["security_settings"]
    check securitySettings.getEnum(EcdsaCurve, "encryption_curve") == EcdsaCurve.secp256r1
    check securitySettings.getEnum(Priority, "session_priority") == Priority.High
    
    let defaults = appConfig["defaults"]
    check defaults.getEnum(SimpleStatus, "new_task_status") == SimpleStatus.Inactive
    check defaults.getEnum(Priority, "default_priority") == Priority.Low
    check defaults.getEnum(EcdsaCurve, "fallback_curve") == EcdsaCurve.secp256k1

# ================================================================================
# Phase 2.7: %*マクロのパフォーマンステスト
# ================================================================================

suite "%* macro performance tests":

  test "Large record with many enum fields":
    # 多数のEnum値を含む大きなRecord
    let largeRecord = %*{
      "status_1": SimpleStatus.Active,
      "status_2": SimpleStatus.Inactive,
      "priority_1": Priority.Low,
      "priority_2": Priority.Medium,
      "priority_3": Priority.High,
      "priority_4": Priority.Critical,
      "curve_1": EcdsaCurve.secp256k1,
      "curve_2": EcdsaCurve.secp256r1,
      "nested": {
        "status_nested": SimpleStatus.Active,
        "priority_nested": Priority.Critical,
        "curve_nested": EcdsaCurve.secp256k1
      }
    }
    
    check largeRecord.kind == ckRecord
    
    # 全てのEnum値が正しく変換されていることを確認
    check largeRecord.getEnum(SimpleStatus, "status_1") == SimpleStatus.Active
    check largeRecord.getEnum(SimpleStatus, "status_2") == SimpleStatus.Inactive
    check largeRecord.getEnum(Priority, "priority_1") == Priority.Low
    check largeRecord.getEnum(Priority, "priority_2") == Priority.Medium
    check largeRecord.getEnum(Priority, "priority_3") == Priority.High
    check largeRecord.getEnum(Priority, "priority_4") == Priority.Critical
    check largeRecord.getEnum(EcdsaCurve, "curve_1") == EcdsaCurve.secp256k1
    check largeRecord.getEnum(EcdsaCurve, "curve_2") == EcdsaCurve.secp256r1
    
    let nested = largeRecord["nested"]
    check nested.getEnum(SimpleStatus, "status_nested") == SimpleStatus.Active
    check nested.getEnum(Priority, "priority_nested") == Priority.Critical
    check nested.getEnum(EcdsaCurve, "curve_nested") == EcdsaCurve.secp256k1 