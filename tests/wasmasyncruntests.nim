# wasmasyncruntests.nim
# WASMランタイム(wasmer/wamstimeなど)でasync_wasmライブラリのテストを実行するスクリプト

import std/[os, osproc, strutils, strformat]

# test_async.nimをWASIバイナリとしてコンパイルして実行
proc main() =
  # ビルドディレクトリの作成
  let binDir = "bin"
  if not dirExists(binDir):
    createDir(binDir)
  
  # コンパイル
  echo "test_async.nimをWASIバイナリとしてコンパイル中..."
  let compileCmd = "nim c -f --nimcache:nimcache-test " &
                  "--outdir:bin --cpu:wasm32 --os:linux " &
                  "--cc:clang -d:wasm32 -d:wasmrt " &
                  "--out:bin/test_async.wasm tests/test_async.nim"
  
  echo "コンパイルコマンド: ", compileCmd
  let (compileOutput, compileExitCode) = execCmdEx(compileCmd)
  
  if compileExitCode != 0:
    echo "コンパイルエラー:"
    echo compileOutput
    quit(1)
  
  # 利用可能なWASMランタイムの検出
  var wasmRuntime = ""
  var runCmd = ""
  
  # 候補ランタイムのチェック
  let runtimes = [
    ("wasmer", "wasmer run"),
    ("wasmtime", "wasmtime"),
    ("wasm3", "wasm3"),
    ("iwasm", "iwasm")
  ]
  
  for (cmd, runPrefix) in runtimes:
    let (_, exitCode) = execCmdEx("which " & cmd)
    if exitCode == 0:
      wasmRuntime = cmd
      runCmd = runPrefix & " bin/test_async.wasm"
      break
  
  if wasmRuntime == "":
    echo "エラー: WASMランタイム(wasmer, wasmtime, wasm3, iwasm)が見つかりません。"
    echo "いずれかのランタイムをインストールしてから再試行してください。"
    quit(1)
  
  # 実行
  echo fmt"WASMランタイム「{wasmRuntime}」でテストを実行します..."
  echo "==============================================="
  let (output, exitCode) = execCmdEx(runCmd)
  
  # 出力結果の表示
  echo output
  
  # 終了コードの処理
  if exitCode != 0:
    echo fmt"テスト実行が失敗しました。終了コード: {exitCode}"
    quit(exitCode)
  else:
    echo "テスト実行が成功しました！"

when isMainModule:
  main() 
