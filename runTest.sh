#!/usr/bin/env bash
set -euo pipefail

# Run make to start dfx in background
make run

# Wait for dfx to be fully ready
echo "Waiting for dfx to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if /root/.local/share/dfx/bin/dfx ping 2>/dev/null; then
    echo "✓ dfx is ready"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for dfx..."
  sleep 1
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "✗ dfx failed to start after $MAX_ATTEMPTS seconds"
  exit 1
fi

cd /application/solidity
forge install
cd /application
nimble test
