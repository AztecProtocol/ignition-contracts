#! /bin/bash

REPO=$(git rev-parse --show-toplevel)

staking_registry_address=$(cat $REPO/.contracts/dev/contract_addresses.json | jq -r '.stakingRegistry')

echo "Staking registry address: $staking_registry_address"

provider_queue_length=$(cast call $staking_registry_address "getProviderQueueLength(uint256)" 1 --rpc-url http://localhost:8545)

echo "Provider queue length: $(cast 2d $provider_queue_length)"
