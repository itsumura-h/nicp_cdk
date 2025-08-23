#!/bin/bash
rm -fr ./*.wasm
rm -fr ./*.wat

echo "nim c -d:release -o:wasi.wasm src/candid_encode_nim_backend/main.nim"
nim c -d:release -o:wasi.wasm src/candid_encode_nim_backend/main.nim

wasm2wat wasi.wasm -o wasi.wat

echo "wasi2ic wasi.wasm main.wasm"
wasi2ic wasi.wasm main.wasm

wasm2wat main.wasm -o main.wat

rm -f wasi.wasm
