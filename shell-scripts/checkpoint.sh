#! /bin/bash

REPO=$(git rev-parse --show-toplevel)

ANVIL_DEFAULT_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

contract_address=$(cat $REPO/.contracts/dev/contract_addresses.json | jq -r '.twapAuction')

echo "Contract address: $contract_address"

cast send $contract_address "checkpoint()" --rpc-url http://localhost:8545 --private-key $ANVIL_DEFAULT_PRIVATE_KEY

