#!/usr/bin/env bash
set -euo pipefail

# Run make to start dfx in background
make run
cd /application/solidity
forge install
cd /application
nimble test
