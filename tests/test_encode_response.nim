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


proc rowTest(fucName:string):bool =
  let motokoResult = callMotokoCanisterFunction(fucName)
  echo "Motoko result: ", motokoResult
  let nimResult = callNimCanisterFunction(fucName)
  echo "Nim result:    ", nimResult
  return motokoResult == nimResult


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

  test "responseNull":
    check rowTest("responseNull")

  test "responseEmpty":
    check rowTest("responseEmpty")
  
  test "bool":
    check rowTest("boolFunc")
  
  test "int":
    check rowTest("intFunc")
  
  test "int8":
    check rowTest("int8Func")

  test "int16":
    check rowTest("int16Func")

  test "int32":
    check rowTest("int32Func")

  test "int64":
    check rowTest("int64Func")

  test "nat":
    check rowTest("natFunc")

  test "nat8":
    check rowTest("nat8Func")

  test "nat16":
    check rowTest("nat16Func")

  test "nat32":
    check rowTest("nat32Func")

  test "nat64":
    check rowTest("nat64Func")
    
  test "float":
    check rowTest("floatFunc")  

  test "text":
    check rowTest("textFunc")

  test "blob":
    check rowTest("blobFunc")

  test "vec nat":
    check rowTest("vecNatFunc")

  test "vec text":
    check rowTest("vecTextFunc")

  test "vec bool":
    check rowTest("vecBoolFunc")

  test "vec int":
    check rowTest("vecIntFunc")

  test "vec vec nat":
    check rowTest("vecVecNatFunc")

  test "vec vec text":
    check rowTest("vecVecTextFunc")

  test "vec vec bool":
    check rowTest("vecVecBoolFunc")

  test "vec vec int":
    check rowTest("vecVecIntFunc")

  test "opt text some":
    check rowTest("optTextSome")

  test "opt text none":
    check rowTest("optTextNone")

  test "opt int some":
    check rowTest("optIntSome")

  test "opt int none":
    check rowTest("optIntNone")

  test "opt nat some":
    check rowTest("optNatSome")

  test "opt nat none":
    check rowTest("optNatNone")

  test "opt float some":
    check rowTest("optFloatSome")

  test "opt float none":
    check rowTest("optFloatNone")

  test "opt bool some":
    check rowTest("optBoolSome")

  test "opt bool none":
    check rowTest("optBoolNone")

  test "record simple":
    check rowTest("recordSimple")

  test "record nested":
    check rowTest("recordNested")