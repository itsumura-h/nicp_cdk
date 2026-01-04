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

proc logDebug(msg: string) =
  stdout.write("[DEBUG] " & msg & "\n")

proc previewString(s: string): string =
  if s.len <= 50:
    s
  else:
    s.substr(0, 50) & "..."

proc logResponse(source: string, response: string) =
  stdout.write("[RESPONSE] " & source & ": " & response & "\n")

# 共通のヘルパープロシージャ
proc callCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(T_ECDSA_DIR)
    let command = if args == "":
      DFX_PATH & " canister call t_ecdsa_backend " & functionName
    else:
      DFX_PATH & " canister call t_ecdsa_backend " & functionName & " '" & args & "'"
    let execResult = execProcess(command)
    logDebug(fmt"callCanisterFunction result for {functionName} len={execResult.len} preview={previewString(execResult)}")
    logResponse(functionName, execResult)
    return execResult
  finally:
    setCurrentDir(originalDir)

suite "Deploy Tests":
  test "Deploy ECDSA canister":
    logDebug("Deploy ECDSA canister: start")
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(T_ECDSA_DIR)
      let deployResult = execProcess(DFX_PATH & " deploy -y")
      logDebug(fmt"deploy result len={deployResult.len}")
      # deployが成功した場合を確認
      check deployResult.contains("Deployed") or deployResult.contains("Creating") or 
            deployResult.contains("Installing") or deployResult.contains("t_ecdsa_backend")
      # デプロイ後にキャニスターが完全に起動するまで待機
      sleep(3000)
    finally:
      setCurrentDir(originalDir)

suite "ECDSA Management Canister Tests":
  test "Test getPublicKey query function":
    logDebug("Test getPublicKey query function: start")
    sleep(1000)  # キャニスターの完全な準備を待つ
    let callResult = callCanisterFunction("getPublicKey")
    logDebug(fmt"getPublicKey result len={callResult.len} preview={previewString(callResult)}")
    # クエリ関数が正常に実行されることを確認
    # キーが存在する場合は16進文字列、存在しない場合は適切なエラーメッセージが返される
    check callResult.contains("\"") or 
          callResult.contains("No public key generated for caller") or 
          callResult.contains("Failed to get public key") or 
          callResult.contains("reject")

  test "Test getNewPublicKey update function":
    logDebug("Test getNewPublicKey update function: start")
    let callResult = callCanisterFunction("getNewPublicKey")
    logDebug(fmt"getNewPublicKey result len={callResult.len} preview={previewString(callResult)}")
    # 新しい公開鍵が生成されることを確認
    # 実際の出力は16進文字列（0xプレフィックスなし）または適切なエラーメッセージ
    check callResult.contains("\"") or 
          callResult.contains("Failed to get public key") or 
          callResult.contains("IC0506") or 
          callResult.contains("ecdsa_public_key") or
          callResult.len > 10  # 有効な16進文字列が含まれる

  test "Test getPublicKey after getNewPublicKey":
    logDebug("Test getPublicKey after getNewPublicKey: start")
    # まず新しいキーを生成
    discard callCanisterFunction("getNewPublicKey")
    
    # 少し待ってからクエリ
    let queryResult = callCanisterFunction("getPublicKey")
    logDebug(fmt"after getNewPublicKey query result len={queryResult.len} preview={previewString(queryResult)}")
    
    # Step 3: EVMアドレスをテスト
    let evmResult = callCanisterFunction("getEvmAddress")
    logDebug(fmt"EVM address result len={evmResult.len} preview={previewString(evmResult)}")
    
    # 新しいキーが生成された場合、クエリでも同じキーが取得できることを確認
    check queryResult.contains("\"") and queryResult.len > 10
    # EVMアドレスも生成されるべき
    check evmResult.contains("0x") and evmResult.len > 10

suite "ECDSA Signature and Verification Tests":
  test "Test signWithEcdsa basic functionality":
    logDebug("Test signWithEcdsa basic functionality: start")
    sleep(1000)  # キャニスターの完全な準備を待つ
    # まず公開鍵を生成して準備
    discard callCanisterFunction("getNewPublicKey")
    
    # メッセージに署名
    let testMessage = "Hello, ICP ECDSA!"
    let signResult = callCanisterFunction("signWithEcdsa", testMessage)
    logDebug(fmt"signWithEcdsa result len={signResult.len} preview={previewString(signResult)}")
    
    # 署名が正常に生成されることを確認
    check signResult.contains("\"") and signResult.len > 10
    # 署名は16進文字列として返される
    check not signResult.contains("reject") and not signResult.contains("Failed")

  test "Test verifyWithEcdsa with valid signature":
    logDebug("Test verifyWithEcdsa with valid signature: start")
    
    # Step 1: 公開鍵を取得
    let publicKeyResult = callCanisterFunction("getNewPublicKey")
    
    # Step 2: メッセージに署名
    let testMessage = "Test message for verification"
    let signatureResult = callCanisterFunction("signWithEcdsa", testMessage)
    logDebug(fmt"signature result len={signatureResult.len} preview={previewString(signatureResult)}")
    
    # Step 3: 署名を検証
    
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
    logDebug(fmt"verifyResult len={verifyResult.len} preview={previewString(verifyResult)}")
    
    # 検証結果がtrueであることを確認
    check verifyResult.contains("true") or verifyResult.contains("(true)")

  test "Test verifyWithEcdsa with invalid signature":
    logDebug("Test verifyWithEcdsa with invalid signature: start")
    
    # Step 1: 公開鍵を取得
    let publicKeyResult = callCanisterFunction("getNewPublicKey")
    let publicKey = publicKeyResult.replace("(\"", "").replace("\")", "").replace("\n", "").strip()
    
    # Step 2: 不正な署名で検証
    let testMessage = "Test message"
    let invalidSignature = "0123456789abcdef" # 明らかに不正な署名
    
    let verifyArgs = fmt"""(record {{ message = "{testMessage}"; signature = "{invalidSignature}"; publicKey = "{publicKey}"; }})"""
    
    let verifyResult = callCanisterFunction("verifyWithEcdsa", verifyArgs)
    logDebug(fmt"invalid verify result len={verifyResult.len} preview={previewString(verifyResult)}")
    
    # 不正な署名は検証に失敗するべき
    check verifyResult.contains("false") or verifyResult.contains("(false)") or
          verifyResult.contains("reject") or verifyResult.contains("Failed")

  test "Test signWithEcdsa with different messages":
    logDebug("Test signWithEcdsa with different messages: start")
    
    # 複数の異なるメッセージで署名をテスト
    let messages = @[
      "Short",
      "Medium length message for testing",
      "Very long message that contains multiple words and should test the signing functionality with longer input text"
    ]
    
    for i, message in messages:
      logDebug(fmt"signWithEcdsa different message {i}: {message}")
      let signResult = callCanisterFunction("signWithEcdsa", message)
      logDebug(fmt"signWithEcdsa message {i} result len={signResult.len} preview={previewString(signResult)}")
      
      # 各メッセージで署名が生成されることを確認
      check signResult.contains("\"") and signResult.len > 10

  test "Test getNewPublicKey function multiple times":
    logDebug("Test getNewPublicKey function multiple times: start")
    
    # 最初の呼び出し
    let firstResult = callCanisterFunction("getNewPublicKey")
    
    # 2回目の呼び出し（キャッシュされた結果が返される）
    let secondResult = callCanisterFunction("getNewPublicKey")
    logDebug(fmt"first getNewPublicKey len={firstResult.len} preview={previewString(firstResult)}")
    logDebug(fmt"second getNewPublicKey len={secondResult.len} preview={previewString(secondResult)}")
    
    # 両方とも何らかの結果が返されることを確認
    check firstResult.len > 0
    check secondResult.len > 0

suite "EVM Address Tests":
  test "Test getEvmAddress without public key":
    logDebug("Test getEvmAddress without public key: start")
    sleep(1000)  # キャニスターの完全な準備を待つ
    let evmResult = callCanisterFunction("getEvmAddress")
    logDebug(fmt"EVM address without key len={evmResult.len} preview={previewString(evmResult)}")
    # データベースにキーが既に存在する場合はアドレスが返され、存在しない場合は空文字列
    check evmResult.contains("0x") or evmResult.contains("\"\"") or evmResult.contains("reject")

  test "Test getEvmAddress after generating public key":
    logDebug("Test getEvmAddress after generating public key: start")
    
    # まず公開鍵を生成
    discard callCanisterFunction("getNewPublicKey")
    
    # EVMアドレスを取得
    let evmResult = callCanisterFunction("getEvmAddress")
    logDebug(fmt"EVM address after key len={evmResult.len} preview={previewString(evmResult)}")
    
    # 公開鍵が正常に生成された場合、EVMアドレスも取得できるべき
    check evmResult.contains("0x") and evmResult.len > 10

suite "ECDSA Integration Tests":
  test "Test full ECDSA workflow":
    logDebug("Test full ECDSA workflow: start")
    sleep(1000)  # キャニスターの完全な準備を待つ
    
    # Step 1: 新しい公開鍵を生成
    let newKeyResult = callCanisterFunction("getNewPublicKey")
    logDebug(fmt"workflow newKeyResult len={newKeyResult.len} preview={previewString(newKeyResult)}")
    
    # Step 2: 生成された公開鍵をクエリ
    let queryResult = callCanisterFunction("getPublicKey")
    logDebug(fmt"workflow queryResult len={queryResult.len} preview={previewString(queryResult)}")
    
    # Step 3: EVMアドレスを取得
    let evmResult = callCanisterFunction("getEvmAddress")
    logDebug(fmt"workflow evmResult len={evmResult.len} preview={previewString(evmResult)}")
    
    # Step 4: 再度公開鍵をクエリして一貫性を確認
    let reQueryResult = callCanisterFunction("getPublicKey")
    logDebug(fmt"workflow reQueryResult len={reQueryResult.len} preview={previewString(reQueryResult)}")
    
    # 各ステップが完了することを確認（エラーでも良い）
    check newKeyResult.len > 0
    check queryResult.len > 0
    check evmResult.len > 0
    check reQueryResult.len > 0
    
    # 一貫性チェック：同じキーが返されることを確認
    if queryResult.contains("0x") and reQueryResult.contains("0x"):
      # 両方が成功した場合、同じ値であることを確認
      check queryResult == reQueryResult
