make run
cd /application/solidity
forge install
cd /application/solidity/script/Counter
./deployCounter.sh
cd /application
nimble test
