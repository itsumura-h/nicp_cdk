Rust製ic0  
https://github.com/dfinity/cdk-rs/blob/main/ic0/src/ic0.rs

C言語のキャニスターを作るサンプル  
https://github.com/dfinity/examples/tree/master/c/reverse

C言語をキャニスターにコンパイルするスクリプト  
https://github.com/ICPorts-labs/chico/blob/main/examples/HelloWorld/build.sh

インターネットコンピュータにおけるC++データ構造の直交永続性：研究  
https://forum.dfinity.org/t/orthogonal-persistence-of-c-data-structures-on-the-internet-computer-a-study/21828

icpp-proのコンパイル設定  
https://github.com/icppWorld/icpp-pro/blob/main/src/icpp/config_default.py

icpp-proのデモソースコード  
https://github.com/icppWorld/icpp-demos

wasi2icのツール  
https://github.com/wasm-forge/wasi2ic

Candidのバイト列をデコードするツール  
https://fxa77-fiaaa-aaaae-aaana-cai.raw.icp0.io/

Candid型定義  
https://github.com/dfinity/candid/blob/master/spec/Candid.md#types

Candidテストデータ  
https://github.com/dfinity/candid/tree/master/test

---
## NimからICPにデプロイ可能なWASMを作る手順
### ic-wasi-polyfillのビルド

```sh
git submodule add -f https://github.com/wasm-forge/ic-wasi-polyfill wasm-tools/ic-wasi-polyfill

cd /application/wasm-tools/ic-wasi-polyfill
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
```
`/application/wasm-tools/ic-wasi-polyfill/target/wasm32-wasip1/release` をNimのビルド時にLinkerに渡す

### NimをWASMにコンパイルする
```sh
cd /application/examples/arg_msg_reply
```

config.nims
```sh
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
```

build.sh
```sh
#!/bin/bash
rm -fr ./*.wasm
rm -fr ./*.wat

echo "nim c -d:release -o:wasi.wasm src/arg_msg_reply_backend/main.nim"
nim c -d:release -o:wasi.wasm src/arg_msg_reply_backend/main.nim

echo "wasi2ic wasi.wasm main.wasm"
wasi2ic wasi.wasm main.wasm
rm -f wasi.wasm
```

dfx.json
```json
{
  "canisters": {
    "arg_msg_reply_backend": {
      "candid": "arg_msg_reply.did",
      "package": "arg_msg_reply_backend",
      "build": "build.sh",
      "main": "src/arg_msg_reply_backend/main.nim",
      "wasm": "main.wasm",
      "type": "custom",
      "metadata": [
        {
          "name": "candid:service"
        }
      ]
    },
  },
  "defaults": {
    "build": {
      "args": "",
      "packtool": ""
    }
  },
  "output_env_file": ".env",
  "version": 1
}
```

- [dfx.json](./examples/arg_msg_reply/dfx.json) を作成 
  - 参考 https://internetcomputer.org/docs/building-apps/developer-tools/dfx-json#full-list-of-configuration-options
- dfxを起動 `dfx stop && dfx start --clean --host 0.0.0.0:4943 --background`
- canisterを作成 `dfx canister create arg_msg_reply_backend`
- `dfx deploy arg_msg_reply_backend`
- 実行 `dfx canister call --query arg_msg_reply_backend greet '("world")'`








---

## 検証のための手順

### Motokoで作ったWASMのWAT形式を確認する
WASMにビルド

```sh
cd /application/src/dfx_hello
dfx stop && dfx start --clean --host 0.0.0.0:4943 --background
dfx canister create dfx_hello_backend
dfx build
```

`/application/src/dfx_hello/.dfx/local/canisters/dfx_hello_backend/dfx_hello_backend.wasm` が出力される  

WASMをWATに変換する
```sh
cd /application/src/dfx_hello
wasm2wat .dfx/local/canisters/dfx_hello_backend/dfx_hello_backend.wasm -o dfx_hello_backend.wat
```

`/application/src/dfx_hello/dfx_hello_backend.wat` が出力される


### RustのICPインターフェースからアーカイブファイルを作る

```sh
cd /application/src/rust_ic0
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
```

`/application/src/rust_ic0/target/wasm32-unknown-unknown/release/libic0.a` が作られる
