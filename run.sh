./reinsall.sh
ndfx cHeaders
# Stop all dfx processes globally
dfx stop
# Stop project-specific dfx processes by visiting each project
for project_dir in /application/examples/*/; do
  if [ -f "$project_dir/dfx.json" ]; then
    echo "Stopping dfx in $project_dir"
    (cd "$project_dir" && dfx stop 2>/dev/null || true)
  fi
done
# Wait for processes to fully stop
sleep 2
# Clean all .dfx directories
find /application/examples -name ".dfx" -type d -exec rm -rf {} + 2>/dev/null || true
dfx start --clean --background --host 0.0.0.0:4943 --domain localhost --domain 0.0.0.0

# Counterスマートコントラクトのデプロイ状態をチェック
echo "Checking Counter contract deployment status..."

# 前回のデプロイ先アドレスを取得（存在しない場合は空）
ADDR=$(jq -r \
  'try (.transactions[] | select(.contractName=="Counter") | .contractAddress) catch empty' \
  solidity/broadcast/deployCounter.s.sol/31337/run-latest.json 2>/dev/null \
  | tail -n1)

echo "Last deployed Counter address: ${ADDR:-<none>}"

# アドレスがある場合のみ、コード有無を確認
if [ -n "$ADDR" ]; then
  # Anvilが起動しているか確認してからコードチェック
  if curl -s -X POST http://anvil:8545 \
    -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' > /dev/null 2>&1; then
    
    CODE=$(curl -s -X POST http://anvil:8545 \
      -H 'Content-Type: application/json' \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$ADDR\",\"latest\"],\"id\":1}" \
      | jq -r .result 2>/dev/null)
    echo "On-chain code: ${CODE:-<error>}"
  else
    echo "Warning: Anvil not accessible at http://anvil:8545, skipping code check"
    CODE="0x"
  fi
else
  CODE="0x"
fi

# 未デプロイなら Foundry でデプロイ
if [ "$CODE" = "0x" ] || [ -z "$CODE" ] || [ "$CODE" = "null" ]; then
  echo "Counter not found on Anvil. Deploying..."
  cd solidity/script/Counter
  ./deployCounter.sh
  cd /application
  
  # 再度、ブロードキャスト成果物から最新アドレスを取得
  ADDR=$(jq -r \
    'try (.transactions[] | select(.contractName=="Counter") | .contractAddress) catch empty' \
    solidity/broadcast/deployCounter.s.sol/31337/run-latest.json 2>/dev/null \
    | tail -n1)
  echo "Counter deployed at address: $ADDR"
else
  echo "Counter already deployed at: $ADDR"
fi
