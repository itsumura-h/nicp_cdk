#!/bin/bash
rm -fr ./*.wasm
rm -fr ./*.wat

echo "nim c -d:release -o:wasi.wasm src/erc20_backend/main.nim"
nim c -d:release -o:wasi.wasm src/erc20_backend/main.nim

echo "wasi2ic wasi.wasm main.wasm"
wasi2ic wasi.wasm main.wasm
rm -f wasi.wasm
