# cd /application
# dfx killall
# rm -rf /application/examples/http_outcall/nim/.dfx
# dfx start --clean --background
# cd /application/examples/http_outcall/motoko
# dfx deploy -y
# dfx canister call motoko_backend transformFunc
# dfx canister call motoko_backend transformFunc --output raw
# dfx canister call motoko_backend transformBody
# dfx canister call motoko_backend transformBody --output raw
# dfx canister call motoko_backend httpRequestArgs
# dfx canister call motoko_backend httpRequestArgs --output raw

cd /application/examples/http_outcall/nim
dfx deploy -y
# dfx canister call nim_backend transformFunc
# dfx canister call nim_backend transformFunc --output raw
# dfx canister call nim_backend transformBody
# dfx canister call nim_backend transformBody --output raw
# dfx canister call nim_backend httpRequestArgs
# dfx canister call nim_backend httpRequestArgs --output raw

dfx canister call nim_backend get_httpbin
# dfx canister call nim_backend get_httpbin --output raw
dfx canister call nim_backend post_httpbin
# dfx canister call nim_backend post_httpbin --output raw