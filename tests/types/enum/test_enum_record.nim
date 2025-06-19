discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_enum_record.nim

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
# Phase 2.3: Record.getEnum機能テスト
# ================================================================================

suite "Record getEnum tests":

  test "Single enum field retrieval":
    # Record内の単一のEnum値取得
    let record = %*{
      "status": SimpleStatus.Active,
      "name": "test_record"
    }
    
    check record.kind == ckRecord
    let status = record.getEnum(SimpleStatus, "status")
    check status == SimpleStatus.Active

  test "Multiple enum fields retrieval":
    # Record内の複数のEnum値取得
    let record = %*{
      "status": SimpleStatus.Inactive,
      "priority": Priority.High,
      "curve": EcdsaCurve.secp256k1,
      "id": 12345
    }
    
    check record.kind == ckRecord
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Inactive
    check record.getEnum(Priority, "priority") == Priority.High
    check record.getEnum(EcdsaCurve, "curve") == EcdsaCurve.secp256k1

  test "Nested record enum field retrieval":
    # ネストしたRecord内のEnum値取得
    let nestedRecord = %*{
      "user": {
        "status": SimpleStatus.Active,
        "preferences": {
          "priority": Priority.Critical,
          "crypto": EcdsaCurve.secp256r1
        }
      },
      "metadata": {
        "system_status": SimpleStatus.Inactive
      }
    }
    
    check nestedRecord.kind == ckRecord
    
    let user = nestedRecord["user"]
    check user.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    
    let preferences = user["preferences"]
    check preferences.getEnum(Priority, "priority") == Priority.Critical
    check preferences.getEnum(EcdsaCurve, "crypto") == EcdsaCurve.secp256r1
    
    let metadata = nestedRecord["metadata"]
    check metadata.getEnum(SimpleStatus, "system_status") == SimpleStatus.Inactive

# ================================================================================
# Phase 2.4: Record[]=演算子のenum対応テスト
# ================================================================================

suite "Record enum assignment tests":

  test "Single enum field assignment":
    # Record内の単一のEnum値設定
    var record = %*{
      "name": "test_record"
    }
    
    # Enum値を設定
    record["status"] = SimpleStatus.Active
    
    # 正しく設定されていることを確認
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Active

  test "Multiple enum fields assignment":
    # Record内の複数のEnum値設定
    var record = %*{
      "id": 12345
    }
    
    # 複数のEnum値を設定
    record["status"] = SimpleStatus.Inactive
    record["priority"] = Priority.High
    record["curve"] = EcdsaCurve.secp256k1
    
    # 全て正しく設定されていることを確認
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Inactive
    check record.getEnum(Priority, "priority") == Priority.High
    check record.getEnum(EcdsaCurve, "curve") == EcdsaCurve.secp256k1

  test "Enum field overwrite":
    # Enum値の上書き
    var record = %*{
      "status": SimpleStatus.Active
    }
    
    # 初期値確認
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    
    # 値を上書き
    record["status"] = SimpleStatus.Inactive
    
    # 上書きされていることを確認
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Inactive

  test "Mixed type field assignment":
    # Enum型と他の型を混在した設定
    var record = %*{
      "id": 12345,
      "name": "test_task",
      "enabled": true
    }
    
    # Enum型のフィールドを設定
    record["status"] = SimpleStatus.Active
    record["priority"] = Priority.Critical
    
    # 全て正しく設定されていることを確認
    check record["id"].getInt() == 12345
    check record["name"].getStr() == "test_task"
    check record.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    check record.getEnum(Priority, "priority") == Priority.Critical
    check record["enabled"].getBool() == true

# ================================================================================
# Phase 2.5: Record機能のエラーハンドリングテスト
# ================================================================================

suite "Record enum error handling tests":

  test "Non-existent field access":
    # 存在しないフィールドへのアクセス
    let record = %*{
      "status": SimpleStatus.Active
    }
    
    expect(KeyError):
      discard record.getEnum(SimpleStatus, "non_existent")

  test "Wrong enum type conversion":
    # 間違ったEnum型での変換
    let record = %*{
      "status": SimpleStatus.Active
    }
    
    # SimpleStatusを設定したフィールドをPriorityとして取得しようとしてエラー
    expect(ValueError):
      discard record.getEnum(Priority, "status")

  test "Non-variant field enum access":
    # Variant以外のフィールドをEnumとして取得しようとしてエラー
    let record = %*{
      "name": "test_record"
    }
    
    expect(ValueError):
      discard record.getEnum(SimpleStatus, "name")

  test "Non-record type enum access":
    # Record以外の型でgetEnumを呼び出してエラー
    let nonRecord = %*"not_a_record"
    
    expect(ValueError):
      discard nonRecord.getEnum(SimpleStatus, "status")

  test "Non-record type enum assignment":
    # Record以外の型で[]=を呼び出してエラー
    var nonRecord = %*"not_a_record"
    
    expect(ValueError):
      nonRecord["status"] = SimpleStatus.Active

# ================================================================================
# Phase 2.6: Record機能の実用的なユースケーステスト
# ================================================================================

suite "Record enum practical use cases":

  test "Management Canister ECDSA public key args":
    # Management CanisterのECDSA公開鍵引数構造
    var ecdsaArgs = %*{
      "canister_id": "rrkah-fqaaa-aaaaa-aaaaq-cai",
      "derivation_path": [],
      "key_id": {
        "name": "test_key"
      }
    }
    
    # key_idにenum値を設定
    var keyId = ecdsaArgs["key_id"]
    keyId["curve"] = EcdsaCurve.secp256k1
    
    # 正しく設定されていることを確認
    check keyId.getEnum(EcdsaCurve, "curve") == EcdsaCurve.secp256k1
    check keyId["name"].getStr() == "test_key"

  test "Task management system record":
    # タスク管理システムのRecord構造
    var taskRecord = %*{
      "id": 1,
      "title": "Important Task",
      "created_at": "2024-01-01",
      "assignee": "user123"
    }
    
    # Enum値を設定
    taskRecord["status"] = SimpleStatus.Active
    taskRecord["priority"] = Priority.High
    
    # 設定された値の確認
    check taskRecord.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    check taskRecord.getEnum(Priority, "priority") == Priority.High
    check taskRecord["id"].getInt() == 1
    check taskRecord["title"].getStr() == "Important Task"

  test "Configuration system with enum defaults":
    # デフォルト値を持つ設定システム
    var config = %*{
      "app_name": "TestApp",
      "version": "1.0.0"
    }
    
    # デフォルトのEnum値を設定
    config["default_status"] = SimpleStatus.Inactive
    config["default_priority"] = Priority.Low
    config["default_curve"] = EcdsaCurve.secp256k1
    
    # 設定値の確認
    check config.getEnum(SimpleStatus, "default_status") == SimpleStatus.Inactive
    check config.getEnum(Priority, "default_priority") == Priority.Low
    check config.getEnum(EcdsaCurve, "default_curve") == EcdsaCurve.secp256k1

  test "Dynamic enum field management":
    # 動的なEnum フィールド管理
    var dynamicRecord = newCRecordEmpty()
    
    # 複数のEnum値を個別に追加
    dynamicRecord["user_status"] = SimpleStatus.Active
    dynamicRecord["task_priority"] = Priority.Critical
    dynamicRecord["crypto_curve"] = EcdsaCurve.secp256r1
    
    # 設定された値の確認
    check dynamicRecord.getEnum(SimpleStatus, "user_status") == SimpleStatus.Active
    check dynamicRecord.getEnum(Priority, "task_priority") == Priority.Critical
    check dynamicRecord.getEnum(EcdsaCurve, "crypto_curve") == EcdsaCurve.secp256r1

# ================================================================================
# Phase 2.7: Record機能のパフォーマンステスト
# ================================================================================

suite "Record enum performance tests":

  test "Large record with many enum fields":
    # 多数のEnumフィールドを持つ大きなRecord
    var largeRecord = newCRecordEmpty()
    
    # 100個のEnum フィールドを設定
    for i in 0..<100:
      let fieldName = "field_" & $i
      let status = if i mod 2 == 0: SimpleStatus.Active else: SimpleStatus.Inactive
      let priority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      let curve = if i mod 2 == 0: EcdsaCurve.secp256k1 else: EcdsaCurve.secp256r1
      
      largeRecord[fieldName & "_status"] = status
      largeRecord[fieldName & "_priority"] = priority
      largeRecord[fieldName & "_curve"] = curve
    
    # 設定された値の確認（一部）
    check largeRecord.getEnum(SimpleStatus, "field_0_status") == SimpleStatus.Active
    check largeRecord.getEnum(Priority, "field_0_priority") == Priority.Low
    check largeRecord.getEnum(EcdsaCurve, "field_0_curve") == EcdsaCurve.secp256k1
    
    check largeRecord.getEnum(SimpleStatus, "field_99_status") == SimpleStatus.Inactive
    check largeRecord.getEnum(Priority, "field_99_priority") == Priority.Critical
    check largeRecord.getEnum(EcdsaCurve, "field_99_curve") == EcdsaCurve.secp256r1

  test "Nested record enum access performance":
    # ネストしたRecord内のEnum値アクセス性能
    let deepNestedRecord = %*{
      "level1": {
        "level2": {
          "level3": {
            "level4": {
              "status": SimpleStatus.Active,
              "priority": Priority.High,
              "curve": EcdsaCurve.secp256k1
            }
          }
        }
      }
    }
    
    # 深いネストからのEnum値取得
    let level4 = deepNestedRecord["level1"]["level2"]["level3"]["level4"]
    check level4.getEnum(SimpleStatus, "status") == SimpleStatus.Active
    check level4.getEnum(Priority, "priority") == Priority.High
    check level4.getEnum(EcdsaCurve, "curve") == EcdsaCurve.secp256k1 