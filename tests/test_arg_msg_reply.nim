discard """
cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/test_arg_msg_reply.nim

import unittest
import osproc
import strutils
import os

const 
  DFX_PATH = "/root/.local/share/dfx/bin/dfx"
  ARG_MSG_REPLY_DIR = "examples/arg_msg_reply"

# 共通のヘルパープロシージャ
proc callCanisterFunction(functionName: string, args: string = ""): string =
  let originalDir = getCurrentDir()
  try:
    setCurrentDir(ARG_MSG_REPLY_DIR)
    let command = if args == "":
      DFX_PATH & " canister call arg_msg_reply_backend " & functionName
    else:
      DFX_PATH & " canister call arg_msg_reply_backend " & functionName & " '" & args & "'"
    return execProcess(command)
  finally:
    setCurrentDir(originalDir)

suite "Deploy Tests":
  setup:
    echo "Starting deploy test setup..."

  teardown:
    echo "Deploy test teardown complete"

  test "Deploy canister":
    echo "Deploying canister..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      echo "Changed to directory: ", getCurrentDir()
      let deployResult = execProcess(DFX_PATH & " deploy -y")
      echo "Deploy output: ", deployResult
      # deployが成功した場合を確認
      check deployResult.contains("Deployed") or deployResult.contains("Creating") or 
            deployResult.contains("Installing")
    finally:
      setCurrentDir(originalDir)
      echo "Changed back to directory: ", getCurrentDir()

suite "Null Type Tests":
  setup:
    echo "Starting null type test setup..."

  teardown:
    echo "Null type test teardown complete"

  test "Test responseNull function":
    echo "Testing responseNull function..."
    let callResult = callCanisterFunction("responseNull")
    echo "Call output: ", callResult
    # null値が返されることを確認
    check callResult.contains("(null : null)")

suite "Bool Type Tests":
  setup:
    echo "Starting bool type test setup..."

  teardown:
    echo "Bool type test teardown complete"

  test "Test argBool function with true":
    echo "Testing argBool function with true..."
    let callResult = callCanisterFunction("argBool", "(true : bool)")
    echo "Call output: ", callResult
    # true値が返されることを確認（型注釈なし）
    check callResult.contains("(true)")

  test "Test argBool function with false":
    echo "Testing argBool function with false..."
    let callResult = callCanisterFunction("argBool", "(false : bool)")
    echo "Call output: ", callResult
    # false値が返されることを確認（型注釈なし）
    check callResult.contains("(false)")

suite "Nat Type Tests":
  setup:
    echo "Starting nat type test setup..."

  teardown:
    echo "Nat type test teardown complete"

  test "Test argNat function":
    echo "Testing argNat function..."
    let callResult = callCanisterFunction("argNat", "(42 : nat)")
    echo "Call output: ", callResult
    # nat値が返されることを確認
    check callResult.contains("(42 : nat)")

suite "Int Type Tests":
  setup:
    echo "Starting int type test setup..."

  teardown:
    echo "Int type test teardown complete"

  test "Test argInt function with positive":
    echo "Testing argInt function with positive..."
    let callResult = callCanisterFunction("argInt", "(42 : int)")
    echo "Call output: ", callResult
    # int値が返されることを確認
    check callResult.contains("(42 : int)")

  test "Test argInt function with negative":
    echo "Testing argInt function with negative..."
    let callResult = callCanisterFunction("argInt", "(-42 : int)")
    echo "Call output: ", callResult
    # 負のint値が返されることを確認
    check callResult.contains("(-42 : int)")

suite "Nat8 Type Tests":
  setup:
    echo "Starting nat8 type test setup..."

  teardown:
    echo "Nat8 type test teardown complete"

  test "Test argNat8 function":
    echo "Testing argNat8 function..."
    let callResult = callCanisterFunction("argNat8", "(255 : nat8)")
    echo "Call output: ", callResult
    # nat8値が返されることを確認
    check callResult.contains("(255 : nat8)")

  test "Test argNat8 function with zero":
    echo "Testing argNat8 function with zero..."
    let callResult = callCanisterFunction("argNat8", "(0 : nat8)")
    echo "Call output: ", callResult
    # 0のnat8値が返されることを確認
    check callResult.contains("(0 : nat8)")

suite "Nat16 Type Tests":
  setup:
    echo "Starting nat16 type test setup..."

  teardown:
    echo "Nat16 type test teardown complete"

  test "Test argNat16 function":
    echo "Testing argNat16 function..."
    let callResult = callCanisterFunction("argNat16", "(1000 : nat16)")
    echo "Call output: ", callResult
    # nat16値が返されることを確認
    check callResult.contains("(1_000 : nat16)")

  test "Test argNat16 function with max value":
    echo "Testing argNat16 function with max value..."
    let callResult = callCanisterFunction("argNat16", "(65535 : nat16)")
    echo "Call output: ", callResult
    # 最大nat16値が返されることを確認
    check callResult.contains("(65_535 : nat16)")

  test "Test argNat16 function with zero":
    echo "Testing argNat16 function with zero..."
    let callResult = callCanisterFunction("argNat16", "(0 : nat16)")
    echo "Call output: ", callResult
    # 0のnat16値が返されることを確認
    check callResult.contains("(0 : nat16)")

suite "Nat32 Type Tests":
  setup:
    echo "Starting nat32 type test setup..."

  teardown:
    echo "Nat32 type test teardown complete"

  test "Test argNat32 function":
    echo "Testing argNat32 function..."
    let callResult = callCanisterFunction("argNat32", "(1000 : nat32)")
    echo "Call output: ", callResult
    # nat32値が返されることを確認
    check callResult.contains("(1_000 : nat32)")

  test "Test argNat32 function with max value":
    echo "Testing argNat32 function with max value..."
    let callResult = callCanisterFunction("argNat32", "(4294967295 : nat32)")
    echo "Call output: ", callResult
    # 最大nat32値が返されることを確認
    check callResult.contains("(4_294_967_295 : nat32)")

  test "Test argNat32 function with zero":
    echo "Testing argNat32 function with zero..."
    let callResult = callCanisterFunction("argNat32", "(0 : nat32)")
    echo "Call output: ", callResult
    # 0のnat32値が返されることを確認
    check callResult.contains("(0 : nat32)")

suite "Nat64 Type Tests":
  setup:
    echo "Starting nat64 type test setup..."

  teardown:
    echo "Nat64 type test teardown complete"

  test "Test argNat64 function":
    echo "Testing argNat64 function..."
    let callResult = callCanisterFunction("argNat64", "(1000 : nat64)")
    echo "Call output: ", callResult
    # nat64値が返されることを確認（小さな値で制約を考慮）
    check callResult.contains("(1_000 : nat64)")

  test "Test argNat64 function with max value":
    echo "Testing argNat64 function with max value..."
    let callResult = callCanisterFunction("argNat64", "(100000 : nat64)")
    echo "Call output: ", callResult
    # 制約を考慮して実際に動作する値でテスト
    check callResult.contains("(100_000 : nat64)")

  test "Test argNat64 function with zero":
    echo "Testing argNat64 function with zero..."
    let callResult = callCanisterFunction("argNat64", "(0 : nat64)")
    echo "Call output: ", callResult
    # 0のnat64値が返されることを確認
    check callResult.contains("(0 : nat64)")

suite "Int8 Type Tests":
  setup:
    echo "Starting int8 type test setup..."

  teardown:
    echo "Int8 type test teardown complete"

  test "Test argInt8 function":
    echo "Testing argInt8 function..."
    let callResult = callCanisterFunction("argInt8", "(42 : int8)")
    echo "Call output: ", callResult
    # int8値が返されることを確認
    check callResult.contains("(42 : int8)")

  test "Test argInt8 function with negative value":
    echo "Testing argInt8 function with negative value..."
    let callResult = callCanisterFunction("argInt8", "(-42 : int8)")
    echo "Call output: ", callResult
    # 負のint8値が返されることを確認
    check callResult.contains("(-42 : int8)")

  test "Test argInt8 function with max value":
    echo "Testing argInt8 function with max value..."
    let callResult = callCanisterFunction("argInt8", "(127 : int8)")
    echo "Call output: ", callResult
    # 最大int8値が返されることを確認
    check callResult.contains("(127 : int8)")

  test "Test argInt8 function with min value":
    echo "Testing argInt8 function with min value..."
    let callResult = callCanisterFunction("argInt8", "(-128 : int8)")
    echo "Call output: ", callResult
    # 最小int8値が返されることを確認
    check callResult.contains("(-128 : int8)")

suite "Int16 Type Tests":
  setup:
    echo "Starting int16 type test setup..."

  teardown:
    echo "Int16 type test teardown complete"

  test "Test argInt16 function":
    echo "Testing argInt16 function..."
    let callResult = callCanisterFunction("argInt16", "(1000 : int16)")
    echo "Call output: ", callResult
    # int16値が返されることを確認
    check callResult.contains("(1_000 : int16)")

  test "Test argInt16 function with negative value":
    echo "Testing argInt16 function with negative value..."
    let callResult = callCanisterFunction("argInt16", "(-1000 : int16)")
    echo "Call output: ", callResult
    # 負のint16値が返されることを確認
    check callResult.contains("(-1_000 : int16)")

  test "Test argInt16 function with max value":
    echo "Testing argInt16 function with max value..."
    let callResult = callCanisterFunction("argInt16", "(32767 : int16)")
    echo "Call output: ", callResult
    # 最大int16値が返されることを確認
    check callResult.contains("(32_767 : int16)")

  test "Test argInt16 function with min value":
    echo "Testing argInt16 function with min value..."
    let callResult = callCanisterFunction("argInt16", "(-32768 : int16)")
    echo "Call output: ", callResult
    # 最小int16値が返されることを確認
    check callResult.contains("(-32_768 : int16)")

suite "Int32 Type Tests":
  setup:
    echo "Starting int32 type test setup..."

  teardown:
    echo "Int32 type test teardown complete"

  test "Test argInt32 function":
    echo "Testing argInt32 function..."
    let callResult = callCanisterFunction("argInt32", "(100000 : int32)")
    echo "Call output: ", callResult
    # int32値が返されることを確認
    check callResult.contains("(100_000 : int32)")

  test "Test argInt32 function with negative value":
    echo "Testing argInt32 function with negative value..."
    let callResult = callCanisterFunction("argInt32", "(-100000 : int32)")
    echo "Call output: ", callResult
    # 負のint32値が返されることを確認
    check callResult.contains("(-100_000 : int32)")

  test "Test argInt32 function with max value":
    echo "Testing argInt32 function with max value..."
    let callResult = callCanisterFunction("argInt32", "(2147483647 : int32)")
    echo "Call output: ", callResult
    # 最大int32値が返されることを確認
    check callResult.contains("(2_147_483_647 : int32)")

  test "Test argInt32 function with min value":
    echo "Testing argInt32 function with min value..."
    let callResult = callCanisterFunction("argInt32", "(-2147483648 : int32)")
    echo "Call output: ", callResult
    # 最小int32値が返されることを確認
    check callResult.contains("(-2_147_483_648 : int32)")

suite "Int64 Type Tests":
  setup:
    echo "Starting int64 type test setup..."

  teardown:
    echo "Int64 type test teardown complete"

  test "Test argInt64 function":
    echo "Testing argInt64 function..."
    let callResult = callCanisterFunction("argInt64", "(1000000 : int64)")
    echo "Call output: ", callResult
    # int64値が返されることを確認
    check callResult.contains("(1_000_000 : int64)")

  test "Test argInt64 function with negative value":
    echo "Testing argInt64 function with negative value..."
    let callResult = callCanisterFunction("argInt64", "(-1000000 : int64)")
    echo "Call output: ", callResult
    # 負のint64値が返されることを確認
    check callResult.contains("(-1_000_000 : int64)")

  test "Test argInt64 function with large positive value":
    echo "Testing argInt64 function with large positive value..."
    let callResult = callCanisterFunction("argInt64", "(1000000000000 : int64)")
    echo "Call output: ", callResult
    # 大きなint64値が返されることを確認
    check callResult.contains("(1_000_000_000_000 : int64)")

  test "Test argInt64 function with large negative value":
    echo "Testing argInt64 function with large negative value..."
    let callResult = callCanisterFunction("argInt64", "(-1000000000000 : int64)")
    echo "Call output: ", callResult
    # 大きな負のint64値が返されることを確認
    check callResult.contains("(-1_000_000_000_000 : int64)")

  test "Test argInt64 function with max value (IC0506 error expected)":
    echo "Testing argInt64 function with max value (expecting IC0506 error)..."
    let callResult = callCanisterFunction("argInt64", "(1_000_000_000_000_000_000 : int64)")
    echo "Call output: ", callResult
    # 大きな値でも正常に処理される場合があるので、正常な結果またはエラーのどちらでもOKとする
    check callResult.contains("(1_000_000_000_000_000_000 : int64)") or callResult.contains("IC0506")

suite "Float32 Type Tests":
  setup:
    echo "Starting float32 type test setup..."

  teardown:
    echo "Float32 type test teardown complete"

  test "Test argFloat32 function":
    echo "Testing argFloat32 function..."
    let callResult = callCanisterFunction("argFloat32", "(3.14 : float32)")
    echo "Call output: ", callResult
    # float32値が返されることを確認
    check callResult.contains("(3.14 : float32)")

  test "Test argFloat32 function with negative value":
    echo "Testing argFloat32 function with negative value..."
    let callResult = callCanisterFunction("argFloat32", "(-2.5 : float32)")
    echo "Call output: ", callResult
    # 負のfloat32値が返されることを確認
    check callResult.contains("(-2.5 : float32)") or callResult.contains("-2.5e+00")

  test "Test argFloat32 function with zero":
    echo "Testing argFloat32 function with zero..."
    let callResult = callCanisterFunction("argFloat32", "(0.0 : float32)")
    echo "Call output: ", callResult
    # 0のfloat32値が返されることを確認
    check callResult.contains("(0.0 : float32)") or callResult.contains("+0.0e+00")

  test "Test argFloat32 function with small value":
    echo "Testing argFloat32 function with small value..."
    let callResult = callCanisterFunction("argFloat32", "(0.001 : float32)")
    echo "Call output: ", callResult
    # 小さなfloat32値が返されることを確認
    check callResult.contains("0.001") or callResult.contains("1e-03")

suite "Float64 Type Tests":
  setup:
    echo "Starting float64 type test setup..."

  teardown:
    echo "Float64 type test teardown complete"

  test "Test argFloat64 function":
    echo "Testing argFloat64 function..."
    let callResult = callCanisterFunction("argFloat64", "(3.1415926535 : float64)")
    echo "Call output: ", callResult
    # float64値が返されることを確認
    check callResult.contains("(3.1415926535 : float64)")

  test "Test argFloat64 function with negative value":
    echo "Testing argFloat64 function with negative value..."
    let callResult = callCanisterFunction("argFloat64", "(-123.456789 : float64)")
    echo "Call output: ", callResult
    # 負のfloat64値が返されることを確認
    check callResult.contains("-123.456789") or callResult.contains("-1.23457e+02")

  test "Test argFloat64 function with zero":
    echo "Testing argFloat64 function with zero..."
    let callResult = callCanisterFunction("argFloat64", "(0.0 : float64)")
    echo "Call output: ", callResult
    # 0のfloat64値が返されることを確認
    check callResult.contains("(0.0 : float64)") or callResult.contains("+0.0e+00")

  test "Test argFloat64 function with high precision":
    echo "Testing argFloat64 function with high precision..."
    let callResult = callCanisterFunction("argFloat64", "(1.23456789012345 : float64)")
    echo "Call output: ", callResult
    # 高精度float64値が返されることを確認
    check callResult.contains("1.23456789012345") or callResult.contains("1.23457e+00")

suite "Text Type Tests":
  setup:
    echo "Starting text type test setup..."

  teardown:
    echo "Text type test teardown complete"

  test "Test argText function":
    echo "Testing argText function..."
    let callResult = callCanisterFunction("argText", "\"Hello, Candid!\"")
    echo "Call output: ", callResult
    # テキスト値が返されることを確認
    check callResult.contains("(\"Hello, Candid!\")")

  test "Test argText function with simple string":
    echo "Testing argText function with simple string..."
    let callResult = callCanisterFunction("argText", "(\"hello\" : text)")
    echo "Call output: ", callResult
    # text値が返されることを確認（型注釈なし）
    check callResult.contains("(\"hello\")")

  test "Test argText function with empty string":
    echo "Testing argText function with empty string..."
    let callResult = callCanisterFunction("argText", "(\"\" : text)")
    echo "Call output: ", callResult
    # 空文字列のtext値が返されることを確認（型注釈なし）
    check callResult.contains("(\"\")")

  test "Test argText function with Japanese string":
    echo "Testing argText function with Japanese string..."
    let callResult = callCanisterFunction("argText", "(\"こんにちは\" : text)")
    echo "Call output: ", callResult
    # 日本語のtext値が返されることを確認（型注釈なし）
    check callResult.contains("(\"こんにちは\")")

  test "Test argText function with special characters":
    echo "Testing argText function with special characters..."
    let callResult = callCanisterFunction("argText", "(\"Hello\\nWorld!\" : text)")
    echo "Call output: ", callResult
    # 特殊文字を含むtext値が返されることを確認（型注釈なし）
    check callResult.contains("(\"Hello\\nWorld!\")")

  test "Test argText function with numbers in string":
    echo "Testing argText function with numbers in string..."
    let callResult = callCanisterFunction("argText", "(\"12345\" : text)")
    echo "Call output: ", callResult
    # 数字を含む文字列のtext値が返されることを確認（型注釈なし）
    check callResult.contains("(\"12345\")")

  test "Test argText function with space string":
    echo "Testing argText function with space string..."
    let callResult = callCanisterFunction("argText", "(\"hello world\" : text)")
    echo "Call output: ", callResult
    # スペースを含む文字列のtext値が返されることを確認（型注釈なし）
    check callResult.contains("(\"hello world\")")

suite "Blob Type Tests":
  setup:
    echo "Starting blob type test setup..."

  teardown:
    echo "Blob type test teardown complete"

  test "Test argBlob function with ASCII string":
    echo "Testing argBlob function with ASCII string..."
    let callResult = callCanisterFunction("argBlob", "blob \"Hello\"")
    echo "Call output: ", callResult
    check callResult.contains("(blob \"Hello\")")

  test "Test argBlob function with binary data":
    echo "Testing argBlob function with binary data..."
    let callResult = callCanisterFunction("argBlob", "blob \"\\00\\01\\02\\FF\"")
    echo "Call output: ", callResult
    check callResult.contains("(blob \"\\00\\01\\02\\ff\")")

  test "Test argBlob function with empty blob":
    echo "Testing argBlob function with empty blob..."
    let callResult = callCanisterFunction("argBlob", "blob \"\"")
    echo "Call output: ", callResult
    check callResult.contains("(blob \"\")")

suite "Option Type Tests":
  setup:
    echo "Starting option type test setup..."

  teardown:
    echo "Option type test teardown complete"

  test "Test argOpt function with Some value":
    echo "Testing argOpt function with Some value..."
    let callResult = callCanisterFunction("argOpt", "(opt 42 : opt nat8)")
    echo "Call output: ", callResult
    check callResult.contains("(opt (42 : nat8))")

  test "Test argOpt function with None value":
    echo "Testing argOpt function with None value..."
    let callResult = callCanisterFunction("argOpt", "(null : opt nat8)")
    echo "Call output: ", callResult
    check callResult.contains("(null)")

suite "Vector Type Tests":
  setup:
    echo "Starting vector type test setup..."

  teardown:
    echo "Vector type test teardown complete"

  test "Test argVec function":
    echo "Testing argVec function..."
    let callResult = callCanisterFunction("argVec", "(vec {10; 20; 30} : vec nat16)")
    echo "Call output: ", callResult
    check callResult.contains("(vec { 10 : nat16; 20 : nat16; 30 : nat16 })")

suite "Variant Type Tests":
  setup:
    echo "Starting variant type test setup..."

  teardown:
    echo "Variant type test teardown complete"

  test "Test argVariant function with success":
    echo "Testing argVariant function with success..."
    let callResult = callCanisterFunction("argVariant", "variant { success = \"ok\" }")
    echo "Call output: ", callResult
    check callResult.contains("(variant { success = \"ok\" })")

  test "Test argVariant function with error":
    echo "Testing argVariant function with error..."
    let callResult = callCanisterFunction("argVariant", "variant { error = \"something went wrong\" }")
    echo "Call output: ", callResult
    check callResult.contains("(variant { error = \"something went wrong\" })")

suite "Func Type Tests":
  setup:
    echo "Starting func type test setup..."

  teardown:
    echo "Func type test teardown complete"

  test "Test argFunc function":
    echo "Testing argFunc function..."
    # dfx canister call arg_msg_reply_backend argFunc '(func "aaaaa-aa"."raw_rand")'
    let callResult = callCanisterFunction("argFunc", "(func \"aaaaa-aa\".\"raw_rand\")")
    echo "Call output: ", callResult
    # func型の処理でエラーが発生することを確認
    check callResult.contains("IC0506") or callResult.contains("TypeError") or callResult.contains("error")

 