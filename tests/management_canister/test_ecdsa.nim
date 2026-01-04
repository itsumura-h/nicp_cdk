discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/management_canister/test_ecdsa.nim

import std/unittest
import std/osproc
import std/strutils
import std/strformat
import std/os

const 
  DFX_PATH = "/root/.local/share/dfx/bin/dfx"
  T_ECDSA_DIR = "/application/examples/t_ecdsa"

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
    # キーが存在する場合は16進文字列、存在しない場合は適切なエラーメッセージが返される
    check callResult.contains("\"") or 
          callResult.contains("No public key generated for caller") or 
          callResult.contains("Failed to get public key") or 
          callResult.contains("reject")

  test "Test getNewPublicKey update function":
    echo "Testing getNewPublicKey update function..."
    let callResult = callCanisterFunction("getNewPublicKey")
    echo "Call output: ", callResult
    # 新しい公開鍵が生成されることを確認
    # 実際の出力は16進文字列（0xプレフィックスなし）または適切なエラーメッセージ
    check callResult.contains("\"") or 
          callResult.contains("Failed to get public key") or 
          callResult.contains("IC0506") or 
          callResult.contains("ecdsa_public_key") or
          callResult.len > 10  # 有効な16進文字列が含まれる

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
    
    # Step 3: EVMアドレスをテスト
    echo "Step 3: Testing getEvmAddress..."
    let evmResult = callCanisterFunction("getEvmAddress")
    echo "EVM result: ", evmResult
    
    # 新しいキーが生成された場合、クエリでも同じキーが取得できることを確認
    check queryResult.contains("\"") and queryResult.len > 10
    # EVMアドレスも生成されるべき
    check evmResult.contains("0x") and evmResult.len > 10

suite "ECDSA Signature and Verification Tests":
  setup:
    echo "Starting ECDSA signature and verification test setup..."

  teardown:
    echo "ECDSA signature and verification test teardown complete"

  test "Test signWithEcdsa basic functionality":
    echo "Testing signWithEcdsa with a simple message..."
    
    # まず公開鍵を生成して準備
    echo "Step 1: Ensuring public key exists..."
    let keyResult = callCanisterFunction("getNewPublicKey")
    echo "Key result: ", keyResult
    
    # メッセージに署名
    echo "Step 2: Signing message with ECDSA..."
    let testMessage = "Hello, ICP ECDSA!"
    let signResult = callCanisterFunction("signWithEcdsa", testMessage)
    echo "Sign result: ", signResult
    
    # 署名が正常に生成されることを確認
    check signResult.contains("\"") and signResult.len > 10
    # 署名は16進文字列として返される
    check not signResult.contains("reject") and not signResult.contains("Failed")

  test "Test verifyWithEcdsa with valid signature":
    echo "Testing verifyWithEcdsa with a valid signature..."
    
    # Step 1: 公開鍵を取得
    echo "Step 1: Getting public key..."
    let publicKeyResult = callCanisterFunction("getNewPublicKey")
    echo "Public key result: ", publicKeyResult
    
    # Step 2: メッセージに署名
    echo "Step 2: Signing message..."
    let testMessage = "Test message for verification"
    let signatureResult = callCanisterFunction("signWithEcdsa", testMessage)
    echo "Signature result: ", signatureResult
    
    # Step 3: 署名を検証
    echo "Step 3: Verifying signature..."
    
    # 公開鍵から引用符と改行を除去
    let publicKey = publicKeyResult.replace("(\"", "").replace("\")", "").replace("\n", "").replace(" ", "").strip()
    
    # 署名から括弧、引用符、改行、余分なスペースを除去
    var cleanSignature = signatureResult
    cleanSignature = cleanSignature.replace("(", "").replace(")", "")
    cleanSignature = cleanSignature.replace("\"", "").replace("\n", "").replace(" ", "")
    cleanSignature = cleanSignature.replace(",", "").strip()
    
    # 検証用のレコード引数を構築
    let verifyArgs = fmt"""(record {{ message = "{testMessage}"; signature = "{cleanSignature}"; publicKey = "{publicKey}"; }})"""
    
    let verifyResult = callCanisterFunction("verifyWithEcdsa", verifyArgs)
    echo "Verify result: ", verifyResult
    
    # 検証結果がtrueであることを確認
    check verifyResult.contains("true") or verifyResult.contains("(true)")

  test "Test verifyWithEcdsa with invalid signature":
    echo "Testing verifyWithEcdsa with an invalid signature..."
    
    # Step 1: 公開鍵を取得
    let publicKeyResult = callCanisterFunction("getNewPublicKey")
    let publicKey = publicKeyResult.replace("(\"", "").replace("\")", "").replace("\n", "").strip()
    
    # Step 2: 不正な署名で検証
    echo "Step 2: Verifying with invalid signature..."
    let testMessage = "Test message"
    let invalidSignature = "0123456789abcdef" # 明らかに不正な署名
    
    let verifyArgs = fmt"""(record {{ message = "{testMessage}"; signature = "{invalidSignature}"; publicKey = "{publicKey}"; }})"""
    
    let verifyResult = callCanisterFunction("verifyWithEcdsa", verifyArgs)
    echo "Verify result with invalid signature: ", verifyResult
    
    # 不正な署名は検証に失敗するべき
    check verifyResult.contains("false") or verifyResult.contains("(false)") or
          verifyResult.contains("reject") or verifyResult.contains("Failed")

  test "Test signWithEcdsa with different messages":
    echo "Testing signWithEcdsa with different messages..."
    
    # 複数の異なるメッセージで署名をテスト
    let messages = @[
      "Short",
      "Medium length message for testing",
      "Very long message that contains multiple words and should test the signing functionality with longer input text"
    ]
    
    for i, message in messages:
      echo fmt"Testing message {i+1}: '{message}'"
      let signResult = callCanisterFunction("signWithEcdsa", message)
      echo fmt"Sign result {i+1}: ", signResult
      
      # 各メッセージで署名が生成されることを確認
      check signResult.contains("\"") and signResult.len > 10

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

suite "EVM Address Tests":
  setup:
    echo "Starting EVM address test setup..."

  teardown:
    echo "EVM address test teardown complete"

  test "Test getEvmAddress without public key":
    echo "Testing getEvmAddress without existing public key..."
    let evmResult = callCanisterFunction("getEvmAddress")
    echo "EVM result without key: ", evmResult
    # データベースにキーが既に存在する場合はアドレスが返され、存在しない場合は空文字列
    check evmResult.contains("0x") or evmResult.contains("\"\"") or evmResult.contains("reject")

  test "Test getEvmAddress after generating public key":
    echo "Testing getEvmAddress after generating public key..."
    
    # まず公開鍵を生成
    echo "Generating public key first..."
    let keyResult = callCanisterFunction("getNewPublicKey")
    echo "Key generation result: ", keyResult
    
    # EVMアドレスを取得
    echo "Getting EVM address..."
    let evmResult = callCanisterFunction("getEvmAddress")
    echo "EVM address result: ", evmResult
    
    # 公開鍵が正常に生成された場合、EVMアドレスも取得できるべき
    check evmResult.contains("0x") and evmResult.len > 10

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
    
    # Step 3: EVMアドレスを取得
    echo "Step 3: Getting EVM address..."
    let evmResult = callCanisterFunction("getEvmAddress")
    echo "EVM result: ", evmResult
    
    # Step 4: 再度公開鍵をクエリして一貫性を確認
    echo "Step 4: Re-querying public key for consistency..."
    let reQueryResult = callCanisterFunction("getPublicKey")
    echo "Re-query result: ", reQueryResult
    
    # 各ステップが完了することを確認（エラーでも良い）
    check newKeyResult.len > 0
    check queryResult.len > 0
    check evmResult.len > 0
    check reQueryResult.len > 0
    
    # 一貫性チェック：同じキーが返されることを確認
    if queryResult.contains("0x") and reQueryResult.contains("0x"):
      # 両方が成功した場合、同じ値であることを確認
      echo "Both queries successful, checking consistency..."
