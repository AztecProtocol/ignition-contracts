#!/bin/bash
ROOT=$(git rev-parse --show-toplevel)

# Admin mint a token to a given address
ADDRESS=$1

SOULBOUND_ADDRESS=$(cat $ROOT/.contracts/dev/contract_addresses.json | jq -r '.soulboundToken')

echo "SOULBOUND_ADDRESS: $SOULBOUND_ADDRESS"
echo "Admin minting token to $ADDRESS"

cast send $SOULBOUND_ADDRESS "adminMint(address,uint8,uint256)" $ADDRESS 0 $RANDOM$RANDOM$RANDOM --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80