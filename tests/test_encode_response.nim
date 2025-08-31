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
    let motokoResult = callMotokoCanisterFunction("bool")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("boolFunc")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "int":
    let motokoResult = callMotokoCanisterFunction("int")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("intFunc")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "int8":
    let motokoResult = callMotokoCanisterFunction("int8")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("int8Func")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "int16":
    let motokoResult = callMotokoCanisterFunction("int16")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("int16Func")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "int32":
    let motokoResult = callMotokoCanisterFunction("int32")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("int32Func")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "int64":
    let motokoResult = callMotokoCanisterFunction("int64")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("int64Func")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  
  test "float64":
    let motokoResult = callMotokoCanisterFunction("float64")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("float64Func")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "text":
    let motokoResult = callMotokoCanisterFunction("text")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("textFunc")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "blob":
    let motokoResult = callMotokoCanisterFunction("blob")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("blobFunc")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "responseNull":
    let motokoResult = callMotokoCanisterFunction("responseNull")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("responseNull")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
  
  test "responseEmpty":
    let motokoResult = callMotokoCanisterFunction("responseEmpty")
    echo "Motoko result: ", motokoResult
    let nimResult = callNimCanisterFunction("responseEmpty")
    echo "Nim result:    ", nimResult
    check motokoResult == nimResult
