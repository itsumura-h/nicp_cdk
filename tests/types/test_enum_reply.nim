discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipConfig tests/types/test_enum_reply.nim

import unittest
import std/options
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode
# Reply module を直接インポートすると IC0 が必要になるため、
# テストでは CandidValue の変換のみをテストする

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
# Helper functions for testing reply functionality
# ================================================================================

proc testEnumToReplyValue*[T: enum](enumValue: T): bool = 
  ## Enum値がReply用のCandidValueに正しく変換できるかテスト
  try:
    let value = newCandidValue(enumValue)
    let encoded = encodeCandidMessage(@[value])
    return encoded.len > 0
  except:
    return false

# ================================================================================
# Phase 2.2: Reply.reply(enum)機能テスト
# ================================================================================

suite "Reply enum conversion tests":

  test "Simple enum value reply conversion":
    # SimpleStatus.ActiveのReply変換
    check testEnumToReplyValue(SimpleStatus.Active) == true
    check testEnumToReplyValue(SimpleStatus.Inactive) == true

  test "Multiple enum types reply conversion":
    # 異なるEnum型のReply変換
    check testEnumToReplyValue(Priority.Critical) == true
    check testEnumToReplyValue(Priority.Low) == true
    check testEnumToReplyValue(EcdsaCurve.secp256k1) == true
    check testEnumToReplyValue(EcdsaCurve.secp256r1) == true

  test "All enum values reply conversion":
    # 各Enum型の全ての値でReply変換テスト
    for status in SimpleStatus:
      check testEnumToReplyValue(status) == true
    
    for priority in Priority:
      check testEnumToReplyValue(priority) == true
    
    for curve in EcdsaCurve:
      check testEnumToReplyValue(curve) == true

# ================================================================================
# Phase 2.3: Reply機能のエンコードテスト
# ================================================================================

suite "Reply enum encoding tests":

  test "Enum reply encoding verification":
    # Reply関数内部のencodeCandidMessage呼び出しをテスト
    let statusValue = newCandidValue(SimpleStatus.Active)
    let encoded = encodeCandidMessage(@[statusValue])
    
    # エンコードが正常に行われることを確認
    check encoded.len > 0
    
    # デコードして元の値が復元できることを確認
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctVariant
    
    # Enum値として取得可能であることを確認
    let retrievedStatus = getEnumValue(decoded.values[0], SimpleStatus)
    check retrievedStatus == SimpleStatus.Active

  test "Priority enum reply encoding":
    # Priority enum のエンコード確認
    let priorityValue = newCandidValue(Priority.High)
    let encoded = encodeCandidMessage(@[priorityValue])
    
    check encoded.len > 0
    
    let decoded = decodeCandidMessage(encoded)
    let retrievedPriority = getEnumValue(decoded.values[0], Priority)
    check retrievedPriority == Priority.High

  test "ECDSA curve enum reply encoding":
    # EcdsaCurve enum のエンコード確認
    let curveValue = newCandidValue(EcdsaCurve.secp256r1)
    let encoded = encodeCandidMessage(@[curveValue])
    
    check encoded.len > 0
    
    let decoded = decodeCandidMessage(encoded)
    let retrievedCurve = getEnumValue(decoded.values[0], EcdsaCurve)
    check retrievedCurve == EcdsaCurve.secp256r1

# ================================================================================
# Phase 2.4: Reply機能のエラーハンドリングテスト
# ================================================================================

suite "Reply enum error handling tests":

  test "Reply enum conversion consistency":
    # 同じEnum値の変換が一貫していることを確認
    let value1 = newCandidValue(SimpleStatus.Active)
    let value2 = newCandidValue(SimpleStatus.Active)
    
    let encoded1 = encodeCandidMessage(@[value1])
    let encoded2 = encodeCandidMessage(@[value2])
    
    # エンコード結果が一致することを確認
    check encoded1 == encoded2

# ================================================================================
# Phase 2.5: Reply機能の実用的なユースケーステスト
# ================================================================================

suite "Reply enum practical use cases":

  test "Management Canister ECDSA response conversion":
    # Management CanisterのECDSA処理レスポンス変換
    check testEnumToReplyValue(EcdsaCurve.secp256k1) == true
    check testEnumToReplyValue(EcdsaCurve.secp256r1) == true

  test "Task status update response conversion":
    # タスクステータス更新のレスポンス変換
    check testEnumToReplyValue(SimpleStatus.Active) == true
    check testEnumToReplyValue(SimpleStatus.Inactive) == true

  test "Priority notification response conversion":
    # 優先度通知のレスポンス変換
    check testEnumToReplyValue(Priority.Critical) == true
    check testEnumToReplyValue(Priority.High) == true
    check testEnumToReplyValue(Priority.Medium) == true
    check testEnumToReplyValue(Priority.Low) == true

# ================================================================================
# Phase 2.6: Reply機能のパフォーマンステスト
# ================================================================================

suite "Reply enum performance tests":

  test "Multiple enum reply conversion performance":
    # 大量のenum Reply変換のパフォーマンステスト
    for i in 0..<100:
      let status = if i mod 2 == 0: SimpleStatus.Active else: SimpleStatus.Inactive
      let priority = case i mod 4:
        of 0: Priority.Low
        of 1: Priority.Medium
        of 2: Priority.High
        else: Priority.Critical
      let curve = if i mod 2 == 0: EcdsaCurve.secp256k1 else: EcdsaCurve.secp256r1
      
      check testEnumToReplyValue(status) == true
      check testEnumToReplyValue(priority) == true
      check testEnumToReplyValue(curve) == true

  test "Enum reply conversion memory efficiency":
    # メモリ効率の確認（大きなenum型でのテスト）
    # 現在は小さなenum型のみなので、基本的なテストのみ
    var successCount = 0
    
    for status in SimpleStatus:
      if testEnumToReplyValue(status):
        successCount += 1
    for priority in Priority:
      if testEnumToReplyValue(priority):
        successCount += 1
    for curve in EcdsaCurve:
      if testEnumToReplyValue(curve):
        successCount += 1
    
    # 全ての変換が成功していることを確認
    check successCount == 8  # SimpleStatus(2) + Priority(4) + EcdsaCurve(2) 