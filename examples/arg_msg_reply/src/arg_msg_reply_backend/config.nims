--mm: "orc"
--threads: "off"
--cpu: "wasm32"
--os: "linux"
--nomain
--cc: "clang" # コンパイラ：clang を利用
--define: "useMalloc"
--nimcache: "./dist"

# WASI ターゲットだが、icpp-pro のように自己完結型にするために静的リンクを強制
switch("passC", "-target wasm32-wasi")
switch("passL", "-target wasm32-wasi")
switch("passL", "-static") # 必要なライブラリ群を静的にリンクする
switch("passL", "-nostartfiles") # 標準のスタートアップコードをリンクしない
switch("passL", "-Wl,--no-entry") # エントリーポイント処理を行わない
switch("passC", "-fno-exceptions")

# ic wasi polyfill のパス指定
switch("passL", "-L/application/wasm-tools/ic-wasi-polyfill/target/wasm32-wasip1/release")
switch("passL", "-lic_wasi_polyfill")

# ic0.h のパス指定
switch("passC", "-I" & "/application/src/nim_ic_cdk/c_headers")
switch("passL", "-L" & "/application/src/nim_ic_cdk/c_headers")

# WASI SDK の sysroot / include 指定
let wasiSysroot = "/root/wasi-sdk-25.0-x86_64-linux/share/wasi-sysroot"
switch("passC", "--sysroot=" & wasiSysroot)
switch("passL", "--sysroot=" & wasiSysroot)
switch("passC", "-I" & wasiSysroot & "/include")

# WASI でのエミュレーション設定
switch("passC", "-D_WASI_EMULATED_SIGNAL")
switch("passL", "-lwasi-emulated-signal")
