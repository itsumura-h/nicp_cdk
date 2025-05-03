NICP - Nim CDK for the Internet Computer (Beta)
===

This is a Nim CDK for the Internet Computer.

## Requirements

- [Nim](https://nim-lang.org/install.html)
- [WASI SDK (this includes Clang)](https://wasi.dev/docs/sdk-install)
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
