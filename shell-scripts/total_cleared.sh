#! /bin/bash

REPO=$(git rev-parse --show-toplevel)

contract_address=$(cat $REPO/.contracts/dev/contract_addresses.json | jq -r '.twapAuction')

echo "Contract address: $contract_address"

amount=$(cast call $contract_address "totalCleared()" --rpc-url http://localhost:8545 | awk '{print $1}')
formatted=$(cast fun $amount)

echo "Total cleared: $formatted"