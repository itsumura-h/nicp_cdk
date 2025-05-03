NICP - Nim CDK for the Internet Computer (Beta)
===

This is a Nim CDK for the Internet Computer.

Why did I choose Nim to develop ICP canisters?

This is because:  
- Nim is a transpiler to C, which allows it to develop for WASM.
- Nim is a high-level language, making it as easy to write and read as Python.
- Nim is the statically typed language.
- Nim has a package manager, which makes it easy to install and manage dependencies.
- Nim has one of the best memory management systems. The compiler automatically controls the lifetime of variables without garbage collection (GC) or manual memory management.

Another motivation essay, [The Strength in Simplicity: The Aesthetics of Japanese Traditional Crafts and Distributed Systems](./docs/en/strength_in_simplicity.md)

## Requirements

- [Nim](https://nim-lang.org/install.html)
- [WASI SDK (this includes Clang)](https://github.com/WebAssembly/wasi-sdk)
- [wasi2ic](https://github.com/wasm-forge/wasi2ic)
- [Internet Computer SDK](https://internetcomputer.org/docs/current/developer-docs/setup/install/sdk-install)

### Optional
- [Nim language server](https://github.com/nim-lang/langserver) (Recommended for Nim development)
- [WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt)
- [Rust](https://www.rust-lang.org/tools/install)

## Installation
See also [Dockerfile](docker/develop.Dockerfile).

This based on Ubuntu or Debian.

```sh
apt install -y \
  build-essential \
  libunwind-dev \
  lldb \
  lld gcc-multilib \
  xz-utils \
  wget \
  curl \
  git
```

### Install Rust
https://www.rust-lang.org/tools/install

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Build ic-wasi-polyfill
```sh
mkdir -p wasm-tools
cd wasm-tools
git clone https://github.com/wasm-forge/ic-wasi-polyfill.git
cd ic-wasi-polyfill
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
```

### Install WASI SDK
https://github.com/WebAssembly/wasi-sdk

```sh
cd /root
WASI_VERSION="25"
WASI_VERSION_FULL="$WASI_VERSION.0"
curl -L -o wasi-sdk.tar.gz https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION_FULL}-x86_64-linux.tar.gz
tar -xzf wasi-sdk.tar.gz
rm wasi-sdk.tar.gz
WASI_SDK_PATH="/root/wasi-sdk-${WASI_VERSION_FULL}"
export PATH=$PATH:"${WASI_SDK_PATH}-x86_64-linux/bin"
echo $WASI_SDK_PATH
```

### Install wasi2ic
https://github.com/wasm-forge/wasi2ic

```sh
cargo install wasi2ic
```

### Install Nim
https://nim-lang.org/install.html

```sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

## Create a new project
```sh
ndfx new hello
cd hello
```

> [!WARNING]
> Check the `hello/src/hello_backend/config.nims` file.  
> is `ic wasi polyfill path` correct?  
> is `WASI SDK sysroot` correct?  

### Build and run local network
```sh
dfx start --clean --background
dfx deploy
```

## Roadmap
- [ ] no need to build ic-wasi-polyfill by yourself
- [ ] support all ic types
- [ ] access and call management canister
- [ ] HTTP outcall example
- [ ] t-ecdsa example
- [ ] t-rsa example
- [ ] Bitcoin example
- [ ] Ethersum example
- [ ] Solana example
- [ ] vetkey example
