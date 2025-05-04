NICP - Nim CDK for the Internet Computer (Beta)
===

This is the Nim CDK for the Internet Computer.

## Why Nim for ICP canisters?

I chose Nim for developing ICP canisters because:
- Nim can be transpiled to C, which allows it to target WebAssembly (WASM).
- Nim is a high-level language, making it as easy to write and read as Python.
- Nim is a statically typed language.
- Nim has a package manager, which makes it easy to install and manage dependencies.
- Nim has one of the best memory management systems: the compiler automatically controls the lifetime of variables without garbage collection (GC) or manual memory management.

Another motivational essay:  
[The Strength in Simplicity: The Aesthetics of Japanese Traditional Crafts and Distributed Systems](./docs/en/strength_in_simplicity.md)

## Requirements

- [Nim](https://nim-lang.org)  
- [WASI SDK (includes Clang)](https://github.com/WebAssembly/wasi-sdk)  
- [ic-wasi-polyfill](https://github.com/wasm-forge/ic-wasi-polyfill)  
- [wasi2ic](https://github.com/wasm-forge/wasi2ic)  
- [Internet Computer SDK](https://internetcomputer.org/docs/current/developer-docs/setup/install/sdk-install)  

### Optional

- [Nim language server](https://github.com/nim-lang/langserver) (recommended for Nim development)  
- [WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt)  
- [Rust](https://www.rust-lang.org) (for building ic-wasi-polyfill)

## Installation

See also [Dockerfile](docker/app/develop.Dockerfile).

These instructions assume Ubuntu or Debian:

```sh
apt install -y \
  build-essential \
  libunwind-dev \
  lldb \
  lld \
  gcc-multilib \
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
cd /root
git clone https://github.com/wasm-forge/ic-wasi-polyfill.git
cd ic-wasi-polyfill
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
export IC_WASI_POLYFILL_PATH "/root/ic-wasi-polyfill/target/wasm32-wasip1/release"
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
mv "wasi-sdk-${WASI_VERSION_FULL}-x86_64-linux" ".wasi-sdk"
export WASI_SDK_PATH "/root/.wasi-sdk"
PATH $PATH:"${WASI_SDK_PATH}/bin"
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

### Install NICP

```sh
nimble install https://github.com/itsumura-h/nicp_cdk
```

Now you can use the `ndfx` command.

## Create a new project

```sh
ndfx new hello
cd hello
```

> [!WARNING]  
> Check the `hello/src/hello_backend/config.nims` file:  
> - Is the `ic wasi polyfill path` correct?  
> - Is the `WASI SDK sysroot` correct?  

### Build and run a local network

```sh
dfx stop && dfx start --clean --background --host 0.0.0.0:4943
dfx deploy
```

## Roadmap

- [ ] No need to manually build ic-wasi-polyfill.  
- [ ] Support all IC types.  
- [ ] Access and call the management canister.  
- [ ] HTTP outcall example.  
- [ ] t-ECDSA example.  
- [ ] t-RSA example.  
- [ ] Bitcoin example.  
- [ ] Ethersum example.  
- [ ] Solana example.  
- [ ] VetKey example.
