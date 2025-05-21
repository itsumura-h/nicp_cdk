# test_async.nims
# 純粋なWASMランタイム(wasmer/wamstimeなど)で実行するための設定

import std/os

# メモリ管理と基本設定
--mm: "orc"
--threads: "off"
--cpu: "wasm32"
--os: "linux"
--cc: "clang"
--define: "useMalloc"
--define: "wasm32"       # WASM32ターゲットを有効化
--define: "testing"      # テストモードを有効化

# WASI APIの使用
--define: "wasmrt"       # WASMランタイム環境を有効化

# コンパイル設定
switch("passC", "-target wasm32-wasi")
switch("passL", "-target wasm32-wasi")
switch("passL", "-static")
switch("passL", "-nostartfiles")
switch("passL", "-Wl,--no-entry")
switch("passC", "-fno-exceptions")

# 最適化設定 (サイズを小さく、最適化レベル高め)
switch("passC", "-Os")
switch("passC", "-flto") 
switch("passL", "-flto")
switch("opt", "size")

# テスト用のキャッシュディレクトリ
switch("nimcache", "nimcache-test")

# wasi-sdkへのパス（環境変数から取得）
let wasiSdkPath = getEnv("WASI_SDK_PATH", "/opt/wasi-sdk")
if dirExists(wasiSdkPath):
  let wasiSysroot = wasiSdkPath / "share/wasi-sysroot"
  switch("passC", "--sysroot=" & wasiSysroot)
  switch("passL", "--sysroot=" & wasiSysroot)
  switch("passC", "-I" & wasiSysroot & "/include")

# WASI エミュレーション設定
switch("passC", "-D_WASI_EMULATED_SIGNAL")
switch("passL", "-lwasi-emulated-signal")

# テスト固有の設定
switch("path", "../")  # ソースディレクトリへのパス
switch("outdir", "bin")  # 出力先ディレクトリ

# 出力ファイル設定
switch("out", "bin/test_async.wasm")

# テスト実行方法
exec "nim js -r " & currentSourcePath().changeFileExt("nim") 
