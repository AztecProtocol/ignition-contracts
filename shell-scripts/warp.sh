#! /bin/bash

NEW_TIMESTAMP=$1

if [ -z "$NEW_TIMESTAMP" ]; then
    echo "Usage: $0 <new_timestamp>"
    exit 1
fi

# Convert decimal to hex for JSON-RPC
timestamp=$(printf "0x%x" $NEW_TIMESTAMP)
data='{"jsonrpc":"2.0","method":"evm_setNextBlockTimestamp","params":["'$timestamp'"],"id":1}'
curl -X POST http://localhost:8545 -H "Content-Type: application/json" -d "$data"
