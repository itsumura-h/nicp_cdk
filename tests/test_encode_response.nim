discard """
  cmd: "nim c --skipUserCfg -d:nimOldCaseObjects $file"
"""
# nim c -r --skipUserCfg tests/test_encode_response.nim

import unittest
import std/os
import std/strutils
import std/osproc

const DFX_PATH = "dfx"
const MOTOKO_DIR = "examples/type_test/motoko"
const NIM_DIR = "examples/type_test/nim"

# 共通のヘルパープロシージャ
proc callMotokoCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(MOTOKO_DIR)
    let command = if args == "":
      DFX_PATH & " canister call motoko_backend " & functionName & " --output raw"
    else:
      DFX_PATH & " canister call motoko_backend " & functionName & " '" & args & "'" & " --output raw"
    echo "Motoko command: ", command
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)

proc callNimCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(NIM_DIR)
    let command = if args == "":
      DFX_PATH & " canister call nim_backend " & functionName & " --output raw"
    else:
      DFX_PATH & " canister call nim_backend " & functionName & " '" & args & "'" & " --output raw"
    echo "Nim command: ", command
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)


proc rowTest(fucName:string) =
  let motokoResult = callMotokoCanisterFunction(fucName)
  echo "Motoko result: ", motokoResult
  let nimResult = callNimCanisterFunction(fucName)
  echo "Nim result:    ", nimResult
  check motokoResult == nimResult


proc deploy() =
  echo "Deploying canisters..."
  let originalDir = getCurrentDir()
  
  try:
    # Motokoキャニスターのデプロイ
    setCurrentDir(MOTOKO_DIR)
    echo "Changed to directory: ", getCurrentDir()
    var deployResult = execProcess(DFX_PATH & " deploy -y")
    echo "Motoko deploy output: ", deployResult
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or deployResult.contains("Installing") or deployResult.contains("backend")
    
    # Nimキャニスターのデプロイ
    setCurrentDir("../" & NIM_DIR.split('/')[^1])  # nimディレクトリに移動
    echo "Changed to directory: ", getCurrentDir()
    deployResult = execProcess(DFX_PATH & " deploy -y")
    echo "Nim deploy output: ", deployResult
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or deployResult.contains("Installing") or deployResult.contains("backend")
    
  finally:
    setCurrentDir(originalDir)
    echo "Changed back to directory: ", getCurrentDir()


suite "Candid compare with Motoko tests":
  deploy()
  
  test "bool":
    rowTest("boolFunc")
  
  test "int":
    rowTest("intFunc")
  
  test "int8":
    rowTest("int8Func")

  test "int16":
    rowTest("int16Func")

  test "int32":
    rowTest("int32Func")

  test "int64":
    rowTest("int64Func")

  test "nat":
    rowTest("natFunc")

  test "nat8":
    rowTest("nat8Func")

  test "nat16":
    rowTest("nat16Func")

  test "nat32":
    rowTest("nat32Func")

  test "nat64":
    rowTest("nat64Func")
    
  test "float":
    rowTest("floatFunc")  

  test "text":
    rowTest("textFunc")

  test "blob":
    rowTest("blobFunc")
  
  test "responseNull":
    rowTest("responseNull")

  test "responseEmpty":
    rowTest("responseEmpty")

  test "vec nat":
    rowTest("vecNatFunc")

  test "vec text":
    rowTest("vecTextFunc")

  test "vec bool":
    rowTest("vecBoolFunc")

  test "vec int":
    rowTest("vecIntFunc")
