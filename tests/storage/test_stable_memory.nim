discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/storage/test_stable_memory.nim

import std/unittest
import std/os
import std/osproc
import std/strformat
import std/strutils

const
  DFX_PATH = "/root/.local/share/dfx/bin/dfx"
  EXAMPLE_DIR = "examples/stable_memory"

proc callCanisterFunction(functionName: string, args: string = ""): string =
  let currentDir = getCurrentDir()
  try:
    setCurrentDir(EXAMPLE_DIR)
    let command = if args == "":
      fmt"{DFX_PATH} canister call stable_memory_backend {functionName}"
    else:
      fmt"{DFX_PATH} canister call stable_memory_backend {functionName} '{args}'"
    return execProcess(command)
  finally:
    setCurrentDir(currentDir)

proc checkStableValueRoundTrip(prefix, args: string, expected: string) =
  discard callCanisterFunction(prefix & "_set", args)
  check callCanisterFunction(prefix & "_get").contains(expected)

proc deploy() =
  echo "Deploying stable memory backend..."
  let currentDir = getCurrentDir()
  try:
    setCurrentDir(EXAMPLE_DIR)
    let result = execProcess(DFX_PATH & " deploy -y")
    echo "Deploy output: ", result
    check result.contains("Deployed") or result.contains("Installing") or result.contains("Creating")
  finally:
    setCurrentDir(currentDir)
    echo "Restored working directory"


suite "stable memory backend tests":
  deploy()

  test "int stable value round trip":
    echo "Testing int stable value..."
    checkStableValueRoundTrip("int", "(42)", "42")

  test "uint stable value round trip":
    echo "Testing uint stable value..."
    checkStableValueRoundTrip("uint", "(99)", "99")

  test "string stable value round trip":
    echo "Testing string stable value..."
    checkStableValueRoundTrip("string", "(\"Hello ICP\")", "\"Hello ICP\"")

  test "principal stable value round trip":
    echo "Testing principal stable value..."
    checkStableValueRoundTrip("principal", "(principal \"aaaaa-aa\")", "aaaaa-aa")

  test "bool stable value round trip":
    echo "Testing bool stable value..."
    checkStableValueRoundTrip("bool", "(true)", "true")

  test "float stable value round trip":
    echo "Testing float32 stable value..."
    checkStableValueRoundTrip("float", "(3.14 : float32)", "3.14")

  test "double stable value round trip":
    echo "Testing float64 stable value..."
    checkStableValueRoundTrip("double", "(3.1415926535 : float64)", "3.1415926535")

  test "char stable value round trip":
    echo "Testing char stable value..."
    checkStableValueRoundTrip("char", "(65)", "65")

  test "byte stable value round trip":
    echo "Testing byte stable value..."
    checkStableValueRoundTrip("byte", "(255)", "255")
