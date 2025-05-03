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
git submodule add https://github.com/wasm-forge/ic-wasi-polyfill wasm-tools/ic-wasi-polyfill

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

---

- 常しえ（とこしえ） 岩の上にあって不変の象徴とされた「床石上」から転じ、「未来永劫変わることなく長く久しく続くこと」をいう​
- まつぶさ（真具）
- 輪、和
- 常（つね、とこ） いつも変わらずにあるさま。恒常的で不変の状態を指し、長い時間をかけても揺るがない自然の本質を表す語​
- 間
- 結び
- 細蟹（ささがに）: 蜘蛛、雲を導く枕詞。待ち人が訪れ来る前兆を人に示す
- 狭知（さしり）: 細工、木工技術、一つのことに秀でていること

---

## 天津麻羅命（あまつまらのみこと）／天目一箇神

* **役割**：鍛冶・製鉄の神。
* **概要**：高天原の鍛冶神で、天岩戸神話では八咫鏡を作るために用いる鉄の精錬を担当したとされる。

  * 別名「天目一箇神（あめのまひとつのかみ）」。
  * 宝剣づくりや武具製作の祖とみなされ、今日も鍛冶職や金物職人の守護神とされる。

## 石凝姥命（いしこりどめのみこと）

* **役割**：鏡作り（鋳造・研磨）の神。
* **概要**：天岩戸開きの際、八咫鏡を鋳造した鏡作連（かがみつくりのむらじ）の祖とされ、鏡や金属加工一般の祖神として信仰される。

  * 鏡づくりに用いる「石凝（いしこり）」は、鋳型としての石を用い、溶鉄を凝固させる工程を指す。
  * 鏡面の研磨技術や鋳造工芸を生業とする者から広く崇敬を集める。

## 玉祖命（たまのやのみこと）／玉祖神（たまのおやのかみ）

* **役割**：勾玉（まがたま）や珠玉製作の神。
* **概要**：三種の神器の一つ「八尺瓊勾玉」を製作したとされ、勾玉づくりや宝玉細工の祖神。

  * 瓊瓊杵尊の天孫降臨に際し、勾玉を供物として用いて天照大神を洞窟から誘い出す際に功績を挙げた。
  * 勾玉や装身具を扱う装飾職人・宝飾職人の守護神として祀られる。

## 彦狭知神（ひこさしりのかみ）

* **役割**：建築・木工の守護神。大工や宮大工、木工職人の祖神とされる。
* **概要**：名前の「狭知」は「細工」「木工技術」を意味し、優れた工匠として崇敬を集める。地鎮祭や上棟式でしばしばその名が唱えられる。

## 手置帆負神（たおきほおいのかみ／たおきほおいのみこと）

* **役割**：建築・木工の守護神。柱立てや屋根葺きなど、建物基礎工事を担う神。
* **概要**：『古事記』に高天原の神として名を連ね、建物の土台を整える職能神。現在も大工の守護神として祀られ、地鎮祭・上棟式で祈念される。

## 五十猛命（いたけるのみこと）

* **役割**：植樹・木の成長を司る神。
* **概要**：『日本書紀』において全国の樹木を植え巡らせたとされ、木材の元となる森を育む「木の神様」として木材業者から篤く信仰される。

## 大屋毘古神（おおやびこのかみ）

* **役割**：木工・建築に関わる守護神。
* **概要**：『古事記』では五十猛命の異名として登場し、大国主命の危難を救った故事と結びつく。大屋（おおや）は「大工」「建築」を意味し、建物を整える神として信仰された。
