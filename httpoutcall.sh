# cd /application
# dfx killall
# rm -rf /application/examples/http_outcall/nim/.dfx
# dfx start --clean --background
cd /application/examples/http_outcall/motoko
dfx deploy -y
dfx canister call motoko_backend transformFunc
dfx canister call motoko_backend transformFunc --output raw
dfx canister call motoko_backend transformBody
dfx canister call motoko_backend transformBody --output raw
dfx canister call motoko_backend httpRequestArgs
dfx canister call motoko_backend httpRequestArgs --output raw

# cd /application/examples/http_outcall/nim
# dfx deploy -y
# dfx canister call nim_backend get_transform_funcion
# dfx canister call nim_backend get_transform_funcion --output raw
