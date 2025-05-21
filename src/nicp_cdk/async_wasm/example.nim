# async_wasmモジュールの使用例

import async_wasm

# 非同期関数を定義
proc fetchData(url: string): Future[string] {.async.} =
  # 実際の実装ではWASM環境からHTTP要求を行う
  echo "Fetching data from ", url
  
  # 非同期の遅延をシミュレート
  await sleepAsync(1000)
  
  result = "Data from " & url

proc processData(data: string): Future[int] {.async.} =
  echo "Processing data: ", data
  
  # 処理をシミュレート
  await sleepAsync(500)
  
  result = data.len

# 複数の非同期処理を組み合わせた例
proc fetchAndProcess(url: string): Future[int] {.async.} =
  let data = await fetchData(url)
  let result = await processData(data)
  return result

# FutureStreamの使用例
proc streamExample(): Future[void] {.async.} =
  var stream = newFutureStream[int]()
  
  # 別のタスクがストリームに書き込む（実際はバックグラウンド処理）
  proc writeToStream() {.async.} =
    for i in 1..5:
      await sleepAsync(200)
      echo "Writing to stream: ", i
      stream.write(i)
  
  # streamExampleの中で並行して読み取りと書き込みを行う
  asyncCheck writeToStream()
  
  # ストリームから読み取り
  for i in 1..5:
    let value = await stream.read()
    echo "Read from stream: ", value

when isMainModule:
  echo "Starting async examples..."
  
  # 単一の非同期処理を実行
  let result1 = waitFor fetchData("https://example.com")
  echo "Result 1: ", result1
  
  # 複合的な非同期処理を実行
  let result2 = waitFor fetchAndProcess("https://example.com/api")
  echo "Result 2: ", result2
  
  # ストリーム例を実行
  waitFor streamExample()
  
  echo "All examples completed"

# WASMでの具体的な実装例（JavaScript環境での実行を想定）
when defined(js):
  # JS側から呼び出せる非同期関数
  proc jsExample(data: cstring): Future[cstring] {.exportc, async.} =
    echo "Received from JS: ", data
    await sleepAsync(1000)
    result = "Processed: " & $data 
