./reinsall.sh
ndfx cHeaders
dfx stop
dfx start --clean --background --host 0.0.0.0:4943
