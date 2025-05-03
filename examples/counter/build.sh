#!/bin/bash
rm -fr ./*.wasm
rm -fr ./*.wat

echo "nim c -d:release -o:wasi.wasm src/counter_backend/main.nim"
nim c -d:release -o:wasi.wasm src/counter_backend/main.nim

# echo "wasm2wat wasi.wasm -o wasi.wat"
# wasm2wat wasi.wasm -o wasi.wat

echo "wasi2ic wasi.wasm main.wasm"
wasi2ic wasi.wasm main.wasm
rm -f wasi.wasm

# echo "wasm2wat main.wasm -o main.wat"
# wasm2wat main.wasm -o main.wat
