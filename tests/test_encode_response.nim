discard """
  cmd: "nim c --skipUserCfg -d:nimOldCaseObjects $file"
"""
# nim c -r --skipUserCfg tests/test_encode_response.nim

import unittest
import std/os
import std/strutils
import std/osproc
import ../src/nicp_cdk/ic_types/candid_message/candid_decode
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/type_transfer
import ../src/nicp_cdk/request
const DFX_PATH = "dfx"
const MOTOKO_DIR = "/application/examples/type_test/motoko"
const NIM_DIR = "/application/examples/type_test/nim"

# 共通のヘルパープロシージャ
proc callMotokoCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(MOTOKO_DIR)
    let command = if args == "":
      DFX_PATH & " canister call motoko_backend " & functionName & " --output raw"
    else:
      DFX_PATH & " canister call motoko_backend " & functionName & " '" & args & "'" & " --output raw"
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
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)


proc rowTest(fucName:string):bool =
  let motokoResult = callMotokoCanisterFunction(fucName)
  let nimResult = callNimCanisterFunction(fucName)
  return motokoResult == nimResult


proc deploy() =
  echo "Deploying canisters..."
  let originalDir = getCurrentDir()
  
  try:
    # Motokoキャニスターのデプロイ
    setCurrentDir(MOTOKO_DIR)
    var deployResult = execProcess(DFX_PATH & " deploy -y")
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or deployResult.contains("Installing") or deployResult.contains("backend")
    
    # Nimキャニスターのデプロイ
    setCurrentDir("../" & NIM_DIR.split('/')[^1])  # nimディレクトリに移動
    deployResult = execProcess(DFX_PATH & " deploy -y")
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or deployResult.contains("Installing") or deployResult.contains("backend")
    
  finally:
    setCurrentDir(originalDir)


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

  test "principal":
    check rowTest("principalFunc")

  test "principal anonymous":
    check rowTest("principalAnonymous")

  test "principal canister":
    check rowTest("principalCanister")

  # ===== Variant tests =====
  type Color = enum
    Red
    Green
    Blue

  test "variant color red":
    let motokoResult = callMotokoCanisterFunction("variantColorRed")
    echo "Motoko result: ", motokoResult
    let motokoBytes = motokoResult.toBytes()
    let motokoDecoded = decodeCandidMessage(motokoBytes)
    let motokoRequest = newMockRequest(motokoDecoded.values)
    let motokoResponse = motokoRequest.getEnum(0, Color)
    
    let nimResult = callNimCanisterFunction("variantColorRed")
    echo "Nim result:    ", nimResult
    let nimBytes = nimResult.toBytes()
    let nimDecoded = decodeCandidMessage(nimBytes)
    let nimRequest = newMockRequest(nimDecoded.values)
    let nimResponse = nimRequest.getEnum(0, Color)
    
    check motokoResponse == nimResponse


  test "variant color green":
    let motokoResult = callMotokoCanisterFunction("variantColorGreen")
    echo "Motoko result: ", motokoResult
    let motokoBytes = motokoResult.toBytes()
    let motokoDecoded = decodeCandidMessage(motokoBytes)
    let motokoRequest = newMockRequest(motokoDecoded.values)
    let motokoResponse = motokoRequest.getEnum(0, Color)
    
    let nimResult = callNimCanisterFunction("variantColorGreen")
    echo "Nim result:    ", nimResult
    let nimBytes = nimResult.toBytes()
    let nimDecoded = decodeCandidMessage(nimBytes)
    let nimRequest = newMockRequest(nimDecoded.values)
    let nimResponse = nimRequest.getEnum(0, Color)
    
    check motokoResponse == nimResponse


  test "variant color blue":
    let motokoResult = callMotokoCanisterFunction("variantColorBlue")
    echo "Motoko result: ", motokoResult
    let motokoBytes = motokoResult.toBytes()
    let motokoDecoded = decodeCandidMessage(motokoBytes)
    let motokoRequest = newMockRequest(motokoDecoded.values)
    let motokoResponse = motokoRequest.getEnum(0, Color)

    let nimResult = callNimCanisterFunction("variantColorBlue")
    echo "Nim result:    ", nimResult
    let nimBytes = nimResult.toBytes()
    let nimDecoded = decodeCandidMessage(nimBytes)
    let nimRequest = newMockRequest(nimDecoded.values)
    let nimResponse = nimRequest.getEnum(0, Color)
    
    check motokoResponse == nimResponse

  # ===== Function (ctFunc) tests =====
  # 自キャニスターの query greet() -> text を関数参照として返すケースを比較
  test "func ref: query () -> (text), self greet":
    let motokoResult = callMotokoCanisterFunction("funcRefTextQuery")
    echo "Motoko result: ", motokoResult
    let motokoBytes = motokoResult.toBytes()
    let motokoDecoded = decodeCandidMessage(motokoBytes)
    let motokoRequest = newMockRequest(motokoDecoded.values)
    let motokoFunc = motokoRequest.getFunc(0)
    echo "Motoko func: ", motokoFunc.repr

    let nimResult = callNimCanisterFunction("funcRefTextQuery")
    echo "Nim result:    ", nimResult
    let nimBytes = nimResult.toBytes()
    let nimDecoded = decodeCandidMessage(nimBytes)
    let nimRequest = newMockRequest(nimDecoded.values)
    let nimFunc = nimRequest.getFunc(0)
    echo "Nim func: ", nimFunc.repr

    check motokoFunc.methodName == nimFunc.methodName
    check motokoFunc.args == nimFunc.args
    check motokoFunc.returns == nimFunc.returns
