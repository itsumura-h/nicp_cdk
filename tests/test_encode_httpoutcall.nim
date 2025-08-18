discard """
  cmd:"nim c --skipUserCfg -d:nimOldCaseObjects $file"
"""
# nim c -r --skipUserCfg -d:nimOldCaseObjects tests/test_encode_httpoutcall.nim

import std/unittest
import std/osproc
import std/os
import std/strutils


const DFX_PATH = "/root/.local/share/dfx/bin/dfx"
const MOTOKO_DIR = "examples/candid_encode/motoko"
const NIM_DIR = "examples/candid_encode/nim"


# 共通のヘルパープロシージャ
proc callMotokoCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(MOTOKO_DIR)
    let command = if args == "":
      DFX_PATH & " canister call candid_encode_motoko_backend " & functionName & " --output raw"
    else:
      DFX_PATH & " canister call candid_encode_motoko_backend " & functionName & " '" & args & "'" & " --output raw"
    echo command
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)

proc callNimCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(NIM_DIR)
    let command = if args == "":
      DFX_PATH & " canister call candid_encode_nim_backend " & functionName & " --output raw"
    else:
      DFX_PATH & " canister call candid_encode_nim_backend " & functionName & " '" & args & "'" & " --output raw"
    echo command
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)


proc deploy() =
  echo "Deploying canister..."
  let originalDir = getCurrentDir()
  try:
    # motoko
    setCurrentDir("/application/examples/candid_encode/motoko")
    echo "Changed to directory: ", getCurrentDir()
    var deployResult = execProcess(DFX_PATH & " deploy -y")
    echo "Deploy output: ", deployResult
    # deployが成功した場合を確認
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or 
          deployResult.contains("Installing")
    # nim
    setCurrentDir("/application/examples/candid_encode/nim")
    echo "Changed to directory: ", getCurrentDir()
    deployResult = execProcess(DFX_PATH & " deploy -y")
    echo "Deploy output: ", deployResult
    # deployが成功した場合を確認
    check deployResult.contains("Deployed") or deployResult.contains("Creating") or 
          deployResult.contains("Installing")
  finally:
    setCurrentDir(originalDir)
    echo "Changed back to directory: ", getCurrentDir()


suite("Candid compare with Motoko tests"):
  deploy()

  test("url"):
    let motokoResult = callMotokoCanisterFunction("url")
    echo motokoResult
    let nimResult = callNimCanisterFunction("url")
    echo nimResult
    check motokoResult == nimResult


  test("maxResponseBytes"):
    let motokoResult = callMotokoCanisterFunction("maxResponseBytes")
    echo motokoResult
    let nimResult = callNimCanisterFunction("maxResponseBytes")
    echo nimResult
    check motokoResult == nimResult
  
  
  test("header"):
    let motokoResult = callMotokoCanisterFunction("header")
    echo motokoResult
    let nimResult = callNimCanisterFunction("header")
    echo nimResult
