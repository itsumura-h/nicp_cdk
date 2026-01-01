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
      fmt"{DFX_PATH} canister call --identity default stable_memory_backend {functionName}"
    else:
      fmt"{DFX_PATH} canister call --identity default stable_memory_backend {functionName} '{args}'"
    return execProcess(command).strip()
  finally:
    setCurrentDir(currentDir)


proc checkStableValueRoundTrip(prefix, args, expected: string) =
  discard callCanisterFunction(prefix & "_set", args)
  check callCanisterFunction(prefix & "_get").contains(expected)

proc deploy() =
  echo "Deploying stable memory backend..."
  let currentDir = getCurrentDir()
  try:
    setCurrentDir(EXAMPLE_DIR)
    let result = execProcess(fmt"{DFX_PATH} deploy -y")
    echo "Deploy output: ", result
    check result.contains("Deployed") or result.contains("Installing") or result.contains("Creating")
  finally:
    setCurrentDir(currentDir)
    echo "Restored working directory"


suite "stable memory backend tests":
  deploy()

  test "int stable value round trip":
    checkStableValueRoundTrip("int", "(42)", "42")

  test "uint stable value round trip":
    checkStableValueRoundTrip("uint", "(99)", "99")

  test "string stable value round trip":
    checkStableValueRoundTrip("string", "(\"Hello ICP\")", "\"Hello ICP\"")

  test "principal stable value round trip":
    checkStableValueRoundTrip("principal", "(principal \"aaaaa-aa\")", "aaaaa-aa")

  test "bool stable value round trip":
    checkStableValueRoundTrip("bool", "(true)", "true")

  test "float stable value round trip":
    checkStableValueRoundTrip("float", "(3.14 : float32)", "3.14")

  test "double stable value round trip":
    checkStableValueRoundTrip("double", "(3.1415926535 : float64)", "3.1415926535")

  test "char stable value round trip":
    checkStableValueRoundTrip("char", "(65)", "65")

  test "byte stable value round trip":
    checkStableValueRoundTrip("byte", "(255)", "255")

  test "seq[int] stable value round trip":
    discard callCanisterFunction("seqInt_reset")
    discard callCanisterFunction("seqInt_set", "(1)")
    var value = callCanisterFunction("seqInt_get", "(0)")
    check value == "(1 : int)"

    discard callCanisterFunction("seqInt_set", "(2)")
    value = callCanisterFunction("seqInt_get", "(1)")
    check value == "(2 : int)"

    discard callCanisterFunction("seqInt_set", "(3)")
    value = callCanisterFunction("seqInt_get", "(2)")
    check value == "(3 : int)"

    discard callCanisterFunction("seqInt_set", "(4)")
    value = callCanisterFunction("seqInt_get", "(3)")
    check value == "(4 : int)"

    discard callCanisterFunction("seqInt_set", "(5)")
    value = callCanisterFunction("seqInt_get", "(4)")
    check value == "(5 : int)"

    discard callCanisterFunction("seqInt_set", "(6)")
    value = callCanisterFunction("seqInt_get", "(5)")
    check value == "(6 : int)"

  test "Table[principal, string]":
    discard callCanisterFunction("table_reset")
    discard callCanisterFunction("table_set", "(\"Hello ICP\")")
    var value = callCanisterFunction("table_get")
    check value == "(\"Hello ICP\")"

    discard callCanisterFunction("table_set", "(\"Hello ICP2\")")
    value = callCanisterFunction("table_get")
    check value == "(\"Hello ICP2\")"

  test "object stable value round trip":
    discard callCanisterFunction("object_set", "(1, \"Alice\", true)")
    var value = callCanisterFunction("object_get")
    check value.contains("id = 1")
    check value.contains("name = \"Alice\"")
    check value.contains("active = true")

    discard callCanisterFunction("object_set", "(2, \"Bob\", false)")
    value = callCanisterFunction("object_get")
    check value.contains("id = 2")
    check value.contains("name = \"Bob\"")
    check value.contains("active = false")
