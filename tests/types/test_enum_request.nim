discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipConfig tests/types/test_enum_request.nim

import unittest
import std/options
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode
import ../../src/nicp_cdk/request

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
# Helper function to create mock Request objects
# ================================================================================

proc createMockRequest(values: seq[CandidValue]): Request =
  ## テスト用のRequestオブジェクトを作成
  newMockRequest(values)

# ================================================================================
# Phase 2.1: Request.getEnum機能テスト
# ================================================================================

suite "Request getEnum tests":

  test "Single enum argument retrieval":
    # SimpleStatus.Activeを引数として持つRequestを作成
    let activeValue = newCandidValue(SimpleStatus.Active)
    let request = createMockRequest(@[activeValue])
    
    # getEnumで取得
    let retrievedEnum = request.getEnum(0, SimpleStatus)
    check retrievedEnum == SimpleStatus.Active

  test "Multiple enum arguments retrieval":
    # 複数のEnum値を引数として持つRequestを作成
    let values = @[
      newCandidValue(SimpleStatus.Inactive),
      newCandidValue(Priority.High),
      newCandidValue(EcdsaCurve.secp256k1)
    ]
    let request = createMockRequest(values)
    
    # 各インデックスから正しくEnum値を取得
    check request.getEnum(0, SimpleStatus) == SimpleStatus.Inactive
    check request.getEnum(1, Priority) == Priority.High
    check request.getEnum(2, EcdsaCurve) == EcdsaCurve.secp256k1

# ================================================================================
# Phase 2.2: エラーハンドリングテスト
# ================================================================================

suite "Request getEnum error handling tests":

  test "Index out of bounds error":
    let values = @[newCandidValue(SimpleStatus.Active)]
    let request = createMockRequest(values)
    
    # インデックス範囲外でのアクセス
    expect(IndexDefect):
      discard request.getEnum(1, SimpleStatus)

  test "Non-variant type error":
    # Variant以外の型でのEnum取得エラー
    let values = @[newCandidText("not_variant")]
    let request = createMockRequest(values)
    
    expect(ValueError):
      discard request.getEnum(0, SimpleStatus)

# ================================================================================
# Phase 2.3: 型安全性テスト
# ================================================================================

suite "Request getEnum type safety tests":

  test "Correct enum type inference":
    # コンパイル時型推論が正しく動作することを確認
    let values = @[
      newCandidValue(SimpleStatus.Active),
      newCandidValue(Priority.Medium),
      newCandidValue(EcdsaCurve.secp256r1)
    ]
    let request = createMockRequest(values)
    
    # 型推論の確認（明示的な型指定なしでもコンパイル通過）
    let status: SimpleStatus = request.getEnum(0, SimpleStatus)
    let priority: Priority = request.getEnum(1, Priority)
    let curve: EcdsaCurve = request.getEnum(2, EcdsaCurve)
    
    check status == SimpleStatus.Active
    check priority == Priority.Medium
    check curve == EcdsaCurve.secp256r1

  test "Enum value consistency":
    # 往復変換での一貫性確認
    for status in SimpleStatus:
      let value = newCandidValue(status)
      let request = createMockRequest(@[value])
      let retrieved = request.getEnum(0, SimpleStatus)
      check retrieved == status
    
    for priority in Priority:
      let value = newCandidValue(priority)
      let request = createMockRequest(@[value])
      let retrieved = request.getEnum(0, Priority)
      check retrieved == priority

# ================================================================================
# Phase 2.4: 実用的なユースケーステスト
# ================================================================================

suite "Request getEnum practical use cases":

  test "Management Canister ECDSA curve selection":
    # Management CanisterのECDSAカーブ選択シナリオ
    let curves = @[
      newCandidValue(EcdsaCurve.secp256k1),
      newCandidValue(EcdsaCurve.secp256r1)
    ]
    
    for i, expectedCurve in @[EcdsaCurve.secp256k1, EcdsaCurve.secp256r1]:
      let request = createMockRequest(@[curves[i]])
      let retrievedCurve = request.getEnum(0, EcdsaCurve)
      check retrievedCurve == expectedCurve

  test "Priority-based task processing":
    # 優先度ベースのタスク処理シナリオ
    let taskRequests = @[
      (@[newCandidValue(Priority.Critical), newCandidText("urgent_task")], Priority.Critical),
      (@[newCandidValue(Priority.Low), newCandidText("background_task")], Priority.Low),
      (@[newCandidValue(Priority.High), newCandidText("important_task")], Priority.High)
    ]
    
    for (values, expectedPriority) in taskRequests:
      let request = createMockRequest(values)
      let priority = request.getEnum(0, Priority)
      let taskName = request.getStr(1)
      
      check priority == expectedPriority
      check taskName.len > 0  # タスク名が正常に取得されることを確認

  test "Status transition validation":
    # ステータス遷移バリデーションシナリオ
    let statusTransitions = @[
      newCandidValue(SimpleStatus.Inactive),
      newCandidValue(SimpleStatus.Active),
      newCandidValue(SimpleStatus.Inactive)
    ]
    
    for i, transition in statusTransitions:
      let request = createMockRequest(@[transition])
      let status = request.getEnum(0, SimpleStatus)
      
      # ステータス値が期待されるものかチェック
      check status in [SimpleStatus.Active, SimpleStatus.Inactive]

# ================================================================================
# Phase 2.5: パフォーマンステスト
# ================================================================================

suite "Request getEnum performance tests":

  test "Large number of enum argument processing":
    # 大量のEnum引数処理の性能テスト
    let numArgs = 100
    var values: seq[CandidValue] = @[]
    
    # 100個のEnum値を生成
    for i in 0..<numArgs:
      let priority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      values.add(newCandidValue(priority))
    
    let request = createMockRequest(values)
    
    # 全ての引数を取得して検証
    for i in 0..<numArgs:
      let expectedPriority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      
      let retrievedPriority = request.getEnum(i, Priority)
      check retrievedPriority == expectedPriority

  test "Mixed type argument processing performance":
    # 混在型引数処理の性能テスト
    var values: seq[CandidValue] = @[]
    let iterations = 50
    
    for i in 0..<iterations:
      values.add(newCandidValue(SimpleStatus.Active))  # Enum
      values.add(newCandidText("test_" & $i))          # Text
      values.add(newCandidNat(uint(i)))                # Nat
      values.add(newCandidValue(Priority.High))        # Enum
    
    let request = createMockRequest(values)
    
    # 各引数を正しく取得できることを確認
    for i in 0..<iterations:
      let baseIndex = i * 4
      check request.getEnum(baseIndex, SimpleStatus) == SimpleStatus.Active
      check request.getStr(baseIndex + 1) == "test_" & $i
      check request.getNat(baseIndex + 2) == uint(i)
      check request.getEnum(baseIndex + 3, Priority) == Priority.High 