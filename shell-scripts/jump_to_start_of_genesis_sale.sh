#! /bin/bash

REPO=$(git rev-parse --show-toplevel)

contract_address=$(cat $REPO/.contracts/dev/contract_addresses.json | jq -r '.genesisSequencerSale')

echo "Contract address: $contract_address"

start_time=$(cast 2d $(cast call $contract_address "saleStartTime()" --rpc-url http://localhost:8545))

echo "Start time: $start_time"
echo "Jumping to start of genesis sale"
cast rpc anvil_setNextBlockTimestamp $start_time

echo "Mining block"
cast rpc anvil_mine


