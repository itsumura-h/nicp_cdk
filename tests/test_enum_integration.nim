discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/test_enum_integration.nim

import std/unittest
import std/osproc
import std/strutils
import std/os
import std/json
import std/times

# ================================================================================
# Phase 3.2: Enum機能の統合テスト（自動dfx deploy & canister call）
# ================================================================================

const ARG_MSG_REPLY_DIR = "examples/arg_msg_reply"

suite "Enum Integration Tests (Phase 3.2)":

  setup:
    # examples/arg_msg_replyディレクトリが存在することを確認
    if not dirExists(ARG_MSG_REPLY_DIR):
      echo "❌ examples/arg_msg_reply directory not found"
      fail()

  test "Auto deploy canister":
    # dfx deployの自動実行
    echo "=== Auto deploying canister ==="
    let deployResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx deploy -y")
    echo "Deploy result: ", deployResult
    
    # デプロイ成功の確認（"Deployed canisters"が含まれていることを確認）
    check "Deployed canisters" in deployResult or "already created" in deployResult

  test "SimpleStatus enum response test":
    # SimpleStatus enumの戻り値テスト
    echo "=== Testing SimpleStatus enum response ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend responseSimpleStatus")
    echo "Response: ", callResult
    
    # "(variant { Active })"形式のレスポンスを確認
    check "variant" in callResult and "Active" in callResult

  test "SimpleStatus enum argument test":
    # SimpleStatus enumの引数・戻り値テスト
    echo "=== Testing SimpleStatus enum argument ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argSimpleStatus '(variant { Inactive })'")
    echo "Response: ", callResult
    
    # "(variant { Inactive })"形式のレスポンスを確認
    check "variant" in callResult and "Inactive" in callResult

  test "Priority enum response test":
    # Priority enumの戻り値テスト
    echo "=== Testing Priority enum response ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend responsePriority")
    echo "Response: ", callResult
    
    # "(variant { High })"形式のレスポンスを確認
    check "variant" in callResult and "High" in callResult

  test "Priority enum argument test":
    # Priority enumの引数・戻り値テスト（Critical値）
    echo "=== Testing Priority enum argument ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argPriority '(variant { Critical })'")
    echo "Response: ", callResult
    
    # "(variant { Critical })"形式のレスポンスを確認
    check "variant" in callResult and "Critical" in callResult

  test "Priority enum all values test":
    # Priority enumの全ての値のテスト
    let values = ["Low", "Medium", "High", "Critical"]
    
    for value in values:
      echo "=== Testing Priority enum value: ", value, " ==="
      let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argPriority '(variant { " & value & " })'")
      echo "Response for ", value, ": ", callResult
      
      # 各値が正しくエコーバックされることを確認
      check "variant" in callResult and value in callResult

  test "EcdsaCurve enum response test":
    # EcdsaCurve enumの戻り値テスト
    echo "=== Testing EcdsaCurve enum response ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend responseEcdsaCurveEnum")
    echo "Response: ", callResult
    
    # "(variant { secp256k1 })"形式のレスポンスを確認
    check "variant" in callResult and "secp256k1" in callResult

  test "EcdsaCurve enum argument test":
    # EcdsaCurve enumの引数・戻り値テスト（secp256r1値）
    echo "=== Testing EcdsaCurve enum argument ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argEcdsaCurveEnum '(variant { secp256r1 })'")
    echo "Response: ", callResult
    
    # "(variant { secp256r1 })"形式のレスポンスを確認
    check "variant" in callResult and "secp256r1" in callResult

  test "EcdsaCurve enum both values test":
    # EcdsaCurve enumの両方の値のテスト
    let curves = ["secp256k1", "secp256r1"]
    
    for curve in curves:
      echo "=== Testing EcdsaCurve enum value: ", curve, " ==="
      let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argEcdsaCurveEnum '(variant { " & curve & " })'")
      echo "Response for ", curve, ": ", callResult
      
      # 各curveが正しくエコーバックされることを確認
      check "variant" in callResult and curve in callResult

  test "Error handling test":
    # 存在しないenum値のエラーハンドリングテスト
    echo "=== Testing error handling for invalid enum value ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argSimpleStatus '(variant { InvalidValue })'")
    echo "Error response: ", callResult
    
    # エラーが適切に発生することを確認（exit codeは0でない）
    let processResult = execCmdEx("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argSimpleStatus '(variant { InvalidValue })'")
    check processResult.exitCode != 0

# ================================================================================
# Phase 3.2: パフォーマンステスト
# ================================================================================

suite "Enum Performance Tests (Phase 3.2)":

  test "Enum processing performance test":
    # 複数回のenum処理パフォーマンステスト
    echo "=== Testing enum processing performance ==="
    
    let startTime = cpuTime()
    
    # 10回連続でenum処理を実行
    for i in 1..10:
      let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argSimpleStatus '(variant { Active })'")
      check "variant" in callResult and "Active" in callResult
    
    let endTime = cpuTime()
    let totalTime = endTime - startTime
    
    echo "Total time for 10 enum calls: ", totalTime, " seconds"
    echo "Average time per call: ", totalTime / 10.0, " seconds"
    
    # パフォーマンスは参考情報として出力のみ（具体的な閾値チェックはしない）
    check true

# ================================================================================
# Phase 3.2: Management Canister連携準備テスト
# ================================================================================

suite "Management Canister Integration Preparation (Phase 3.2)":

  test "ECDSA curve enum for Management Canister":
    # Management Canister連携のためのECDSA curve enum準備テスト
    echo "=== Testing ECDSA curve enum for Management Canister ==="
    
    # secp256k1のテスト
    let secp256k1Result = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argEcdsaCurveEnum '(variant { secp256k1 })'")
    echo "secp256k1 result: ", secp256k1Result
    check "variant" in secp256k1Result and "secp256k1" in secp256k1Result
    
    # secp256r1のテスト
    let secp256r1Result = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend argEcdsaCurveEnum '(variant { secp256r1 })'")
    echo "secp256r1 result: ", secp256r1Result
    check "variant" in secp256r1Result and "secp256r1" in secp256r1Result

  test "Simple ECDSA response test":
    # シンプルなECDSA関連レスポンステスト
    echo "=== Testing simple ECDSA response ==="
    let callResult = execProcess("cd " & ARG_MSG_REPLY_DIR & " && dfx canister call arg_msg_reply_backend responseEcdsaPublicKeyArgsEnum")
    echo "ECDSA response: ", callResult
    
    # EcdsaCurve enum値がレスポンスに含まれることを確認
    check "variant" in callResult and "secp256k1" in callResult

# ================================================================================
# テスト実行用ヘルパー関数
# ================================================================================

proc runIntegrationTest*() =
  ## 統合テストの実行
  echo "=== Starting Enum Integration Tests (Phase 3.2) ==="
  
  # カレントディレクトリの確認
  echo "Current directory: ", getCurrentDir()
  
  # examples/arg_msg_replyディレクトリの確認
  if dirExists(ARG_MSG_REPLY_DIR):
    echo "✅ Found examples/arg_msg_reply directory"
  else:
    echo "❌ examples/arg_msg_reply directory not found"
    return
  
  echo "=== Integration tests ready to run ==="

when isMainModule:
  runIntegrationTest() 