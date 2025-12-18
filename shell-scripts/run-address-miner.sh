#!/bin/bash

# Run the address miner with given inputs
ROOT=$(git rev-parse --show-toplevel)

$ROOT/test/integration/token-laucher-address-miner/target/release/uni-v4-hook-address-miner $@
