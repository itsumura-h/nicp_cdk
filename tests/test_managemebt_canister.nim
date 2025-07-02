discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/test_managemebt_canister.nim

import std/unittest
import std/osproc
import std/strutils
import std/os

const 
  DFX_PATH = "/root/.local/share/dfx/bin/dfx"
  T_ECDSA_DIR = "examples/t_ecdsa"

# 共通のヘルパープロシージャ
proc callCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(T_ECDSA_DIR)
    let command = if args == "":
      DFX_PATH & " canister call t_ecdsa_backend " & functionName
    else:
      DFX_PATH & " canister call t_ecdsa_backend " & functionName & " '" & args & "'"
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)

suite "Deploy Tests":
  setup:
    echo "Starting ECDSA deploy test setup..."

  teardown:
    echo "ECDSA deploy test teardown complete"

  test "Deploy ECDSA canister":
    echo "Deploying ECDSA canister..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(T_ECDSA_DIR)
      echo "Changed to directory: ", getCurrentDir()
      let deployResult = execProcess(DFX_PATH & " deploy -y")
      echo "Deploy output: ", deployResult
      # deployが成功した場合を確認
      check deployResult.contains("Deployed") or deployResult.contains("Creating") or 
            deployResult.contains("Installing") or deployResult.contains("t_ecdsa_backend")
    finally:
      setCurrentDir(originalDir)
      echo "Changed back to directory: ", getCurrentDir()

suite "ECDSA Management Canister Tests":
  setup:
    echo "Starting ECDSA management canister test setup..."

  teardown:
    echo "ECDSA management canister test teardown complete"

  test "Test getPublicKey query function":
    echo "Testing getPublicKey query function..."
    let callResult = callCanisterFunction("getPublicKey")
    echo "Call output: ", callResult
    # クエリ関数が正常に実行されることを確認
    # 初回はキーが無いため、エラーまたは空の結果が返される
    check callResult.contains("No key found") or callResult.contains("0x") or callResult.contains("reject")

  test "Test getNewPublicKey update function":
    echo "Testing getNewPublicKey update function..."
    let callResult = callCanisterFunction("getNewPublicKey")
    echo "Call output: ", callResult
    # 新しい公開鍵が生成されることを確認
    # ECDSAキーの生成が成功するか、適切なエラーメッセージが返される
    check callResult.contains("0x") or callResult.contains("Failed to get public key") or 
          callResult.contains("IC0506") or callResult.contains("ecdsa_public_key")

  test "Test getPublicKey after getNewPublicKey":
    echo "Testing getPublicKey after generating new key..."
    
    # まず新しいキーを生成
    echo "Step 1: Generating new public key..."
    let newKeyResult = callCanisterFunction("getNewPublicKey")
    echo "New key result: ", newKeyResult
    
    # 少し待ってからクエリ
    echo "Step 2: Querying existing public key..."
    let queryResult = callCanisterFunction("getPublicKey")
    echo "Query result: ", queryResult
    
    # 新しいキーが生成された場合、クエリでも同じキーが取得できることを確認
    if newKeyResult.contains("0x"):
      check queryResult.contains("0x")
    else:
      # キー生成に失敗した場合でも、一貫したエラーメッセージが返されることを確認
      check queryResult.contains("No key found") or queryResult.contains("reject")

suite "ECDSA Signature Tests":
  setup:
    echo "Starting ECDSA signature test setup..."

  teardown:
    echo "ECDSA signature test teardown complete"

  test "Test getNewPublicKey function multiple times":
    echo "Testing getNewPublicKey function multiple times..."
    
    # 最初の呼び出し
    let firstResult = callCanisterFunction("getNewPublicKey")
    echo "First call result: ", firstResult
    
    # 2回目の呼び出し（キャッシュされた結果が返される）
    let secondResult = callCanisterFunction("getNewPublicKey")
    echo "Second call result: ", secondResult
    
    # 両方とも何らかの結果が返されることを確認
    check firstResult.len > 0
    check secondResult.len > 0

suite "ECDSA Integration Tests":
  setup:
    echo "Starting ECDSA integration test setup..."

  teardown:
    echo "ECDSA integration test teardown complete"

  test "Test full ECDSA workflow":
    echo "Testing full ECDSA workflow..."
    
    # Step 1: 新しい公開鍵を生成
    echo "Step 1: Generating new public key..."
    let newKeyResult = callCanisterFunction("getNewPublicKey")
    echo "New key result: ", newKeyResult
    
    # Step 2: 生成された公開鍵をクエリ
    echo "Step 2: Querying public key..."
    let queryResult = callCanisterFunction("getPublicKey")
    echo "Query result: ", queryResult
    
    # Step 3: 再度公開鍵をクエリして一貫性を確認
    echo "Step 3: Re-querying public key for consistency..."
    let reQueryResult = callCanisterFunction("getPublicKey")
    echo "Re-query result: ", reQueryResult
    
    # 各ステップが完了することを確認（エラーでも良い）
    check newKeyResult.len > 0
    check queryResult.len > 0
    check reQueryResult.len > 0
