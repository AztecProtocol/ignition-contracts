#! /bin/bash

NUMBER_OF_BLOCKS=$1

if [ -z "$NUMBER_OF_BLOCKS" ]; then
    echo "Usage: $0 <number_of_blocks>"
    exit 1
fi

# Convert decimal to hex for JSON-RPC
hex_blocks=$(printf "0x%x" $NUMBER_OF_BLOCKS)
data='{"jsonrpc":"2.0","method":"hardhat_mine","params":["'$hex_blocks'"],"id":1}'
echo "Mining $NUMBER_OF_BLOCKS blocks (hex: $hex_blocks)"
curl -X POST http://localhost:8545 -H "Content-Type: application/json" -d "$data"