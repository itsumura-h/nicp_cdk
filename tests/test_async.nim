# test_async.nim
# async_wasmモジュールの単体テスト
# 純粋なWASMランタイム(wasmer/wamstimeなど)で動作するテスト

import unittest
import std/strutils
import std/strformat
when defined(wasm) or defined(wasm32):
  import std/assertions
  import std/terminal
import std/streams  # 標準出力処理のため

import ../src/nicp_cdk/async_wasm/async_wasm

# 標準出力関数
proc print(msg: string) =
  stdout.write(msg)
  stdout.write("\n")
  flushFile(stdout)

# WASMランタイム向けの設定
when defined(wasm) or defined(wasm32):
  {.pragma: wasmTest.}
else:
  {.pragma: wasmTest, error: "このテストはWASM環境でのみ実行できます".}

# テスト結果カウンター
var
  totalTests = 0
  passedTests = 0
  failedTests = 0

# カスタムチェック関数
template check*(condition: bool, message: string = "") =
  inc totalTests
  if condition:
    inc passedTests
    print fmt"[PASS] {message}"
  else:
    inc failedTests
    print fmt"[FAIL] {message}"

# 基本的な非同期機能をテスト
proc testBasicFutures() =
  print "===== Futureの基本操作 ====="
  
  block:
    let fut = newFuture[int]("testBasicFutures")
    check(not fut.finished(), "新しいFutureは完了状態ではない")
    
    # 完了状態にする
    complete(fut, 42)
    check(fut.finished(), "completeを呼ぶとFutureは完了状態になる")
    check(not fut.failed(), "エラーなしで完了したFutureはfailed()でfalseを返す")
    check(fut.read() == 42, "Futureの値が正しく保存される")
  
  print "===== コールバック機能 ====="
  
  block:
    var callbackCalled = false
    let fut = newFuture[void]("testCallbacks")
    
    fut.callback(proc() = 
      callbackCalled = true
    )
    
    # Futureを完了状態にする前はコールバックは呼ばれない
    check(not callbackCalled, "完了前はコールバックは呼ばれない")
    
    # Futureを完了状態にする
    complete(fut)
    check(callbackCalled, "Futureが完了するとコールバックが呼ばれる")

# 非同期関数のテスト
proc testAsyncFunctions() =
  print "===== 非同期関数 ====="
  
  # 非同期関数の定義
  proc simpleAsyncFunc(): Future[int] {.async.} =
    result = 42
  
  proc delayedAsyncFunc(): Future[string] {.async.} =
    await sleepAsync(10)  # 少し遅延を入れる
    result = "完了"
  
  proc chainedAsyncFunc(): Future[int] {.async.} =
    let s = await delayedAsyncFunc()
    result = s.len
  
  # テスト実行
  block:
    let res = waitFor simpleAsyncFunc()
    check(res == 42, "シンプルな非同期関数が正しい値を返す")
  
  block:
    let res = waitFor delayedAsyncFunc()
    check(res == "完了", "遅延のある非同期関数が正しい値を返す")
  
  block:
    let res = waitFor chainedAsyncFunc()
    check(res == 2, "連鎖した非同期関数が正しい値を返す")

# FutureStreamのテスト
proc testFutureStream() =
  print "===== FutureStreamの操作 ====="
  
  var stream = newFutureStream[int]("testFutureStream")
  
  # 値を書き込む
  stream.write(1)
  stream.write(2)
  stream.write(3)
  
  # 値を読み取る
  let value1 = waitFor stream.read()
  check(value1 == 1, "ストリームから最初の値を読み取り")
  
  let value2 = waitFor stream.read()
  check(value2 == 2, "ストリームから次の値を読み取り")
  
  let value3 = waitFor stream.read()
  check(value3 == 3, "ストリームから最後の値を読み取り")

# WASM固有のテスト
proc testWasmSpecific() {.wasmTest.} =
  print "===== WASM環境固有テスト ====="
  
  when defined(wasm) or defined(wasm32):
    proc wasmAsyncFunc(): Future[int] {.async.} =
      await sleepAsync(50)
      result = 100
    
    let res = waitFor wasmAsyncFunc()
    check(res == 100, "WASM環境での非同期関数の実行")
    
    # 複数の非同期処理の実行
    proc task1(): Future[int] {.async.} =
      await sleepAsync(30)
      result = 1
    
    proc task2(): Future[int] {.async.} =
      await sleepAsync(20)
      result = 2
    
    # 両方のタスクを開始
    let fut1 = task1()
    let fut2 = task2()
    
    # 両方が完了するのを待つ
    let res1 = waitFor fut1
    let res2 = waitFor fut2
    
    check(res1 == 1, "複数の非同期タスク（その1）")
    check(res2 == 2, "複数の非同期タスク（その2）")

# スリープのテスト
proc testSleepAsync() =
  print "===== sleepAsyncのテスト ====="
  
  var done = false
  
  proc sleepTest(): Future[void] {.async.} =
    await sleepAsync(50)
    done = true
  
  # sleepAsyncの前はfalse
  check(not done, "sleepAsync実行前はフラグはfalse")
  
  # sleepAsync実行
  discard waitFor sleepTest()
  
  # sleepAsync完了後はtrue
  check(done, "sleepAsync完了後はフラグがtrue")

# テスト実行関数
proc runTests() =
  print "WASM ランタイムでのテスト実行を開始します..."
  
  # 各テストブロックを実行
  testBasicFutures()
  testAsyncFunctions()
  testFutureStream()
  testSleepAsync()
  
  when defined(wasm) or defined(wasm32):
    testWasmSpecific()
  
  # テスト結果をレポート
  print "===== テスト実行結果 ====="
  print fmt"合計テスト数: {totalTests}"
  print fmt"成功: {passedTests}"
  print fmt"失敗: {failedTests}"
  
  # 戻り値として失敗数を返す（WAMSランタイムの終了コードに使用可能）
  when defined(wasm) or defined(wasm32):
    quit(failedTests)

# メインプログラム
when isMainModule:
  # WASIランタイムで実行できるようにする
  runTests()
