#!/usr/bin/env bash
set -euo pipefail

make run
cd /application/solidity
forge install
cd /application
nimble test
