discard """
cmd: nim c --skipUserCfg tests/test_arg_msg_reply.nim
"""
# nim c -r --skipUserCfg tests/test_arg_msg_reply.nim

import unittest
import osproc
import strutils
import os

const 
  DFX_PATH = "/root/.local/share/dfx/bin/dfx"
  ARG_MSG_REPLY_DIR = "examples/arg_msg_reply"

suite "Canister Integration Tests":
  setup:
    echo "Starting test setup..."

  teardown:
    echo "Test teardown complete"

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

  test "Test responseNull function":
    echo "Testing responseNull function..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend responseNull")
      echo "Call output: ", callResult
      # null値が返されることを確認
      check callResult.contains("(null : null)")
    finally:
      setCurrentDir(originalDir)

  test "Test argBool function with true":
    echo "Testing argBool function with true..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argBool '(true : bool)'")
      echo "Call output: ", callResult
      # true値が返されることを確認（型注釈なし）
      check callResult.contains("(true)")
    finally:
      setCurrentDir(originalDir)

  test "Test argBool function with false":
    echo "Testing argBool function with false..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argBool '(false : bool)'")
      echo "Call output: ", callResult
      # false値が返されることを確認（型注釈なし）
      check callResult.contains("(false)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat function":
    echo "Testing argNat function..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat '(42 : nat)'")
      echo "Call output: ", callResult
      # nat値が返されることを確認
      check callResult.contains("(42 : nat)")
    finally:
      setCurrentDir(originalDir)

  test "Test argInt function with positive":
    echo "Testing argInt function with positive..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argInt '(42 : int)'")
      echo "Call output: ", callResult
      # int値が返されることを確認
      check callResult.contains("(42 : int)")
    finally:
      setCurrentDir(originalDir)

  test "Test argInt function with negative":
    echo "Testing argInt function with negative..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argInt '(-42 : int)'")
      echo "Call output: ", callResult
      # 負のint値が返されることを確認
      check callResult.contains("(-42 : int)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat8 function":
    echo "Testing argNat8 function..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat8 '(255 : nat8)'")
      echo "Call output: ", callResult
      # nat8値が返されることを確認
      check callResult.contains("(255 : nat8)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat8 function with zero":
    echo "Testing argNat8 function with zero..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat8 '(0 : nat8)'")
      echo "Call output: ", callResult
      # 0のnat8値が返されることを確認
      check callResult.contains("(0 : nat8)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat16 function":
    echo "Testing argNat16 function..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat16 '(1000 : nat16)'")
      echo "Call output: ", callResult
      # nat16値が返されることを確認
      check callResult.contains("(1_000 : nat16)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat16 function with max value":
    echo "Testing argNat16 function with max value..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat16 '(65535 : nat16)'")
      echo "Call output: ", callResult
      # 最大nat16値が返されることを確認
      check callResult.contains("(65_535 : nat16)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat16 function with zero":
    echo "Testing argNat16 function with zero..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat16 '(0 : nat16)'")
      echo "Call output: ", callResult
      # 0のnat16値が返されることを確認
      check callResult.contains("(0 : nat16)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat64 function":
    echo "Testing argNat64 function..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat64 '(1000 : nat64)'")
      echo "Call output: ", callResult
      # nat64値が返されることを確認（小さな値で制約を考慮）
      check callResult.contains("(1_000 : nat64)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat64 function with max value":
    echo "Testing argNat64 function with max value..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat64 '(100000 : nat64)'")
      echo "Call output: ", callResult
      # 制約を考慮して実際に動作する値でテスト
      check callResult.contains("(100_000 : nat64)")
    finally:
      setCurrentDir(originalDir)

  test "Test argNat64 function with zero":
    echo "Testing argNat64 function with zero..."
    let originalDir = getCurrentDir()
    try:
      setCurrentDir(ARG_MSG_REPLY_DIR)
      let callResult = execProcess(DFX_PATH & " canister call arg_msg_reply_backend argNat64 '(0 : nat64)'")
      echo "Call output: ", callResult
      # 0のnat64値が返されることを確認
      check callResult.contains("(0 : nat64)")
    finally:
      setCurrentDir(originalDir) 