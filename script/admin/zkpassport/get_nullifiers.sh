#!/bin/bash
ROOT=$(git rev-parse --show-toplevel)

nullifiers_file="$ROOT/utilities/nullifier-extractor/nullifiers.json"

START_INDEX=${1:-0}
CHUNK_SIZE=${2:-1000}

nullifiers=$(jq -r ".[$START_INDEX:$START_INDEX+$CHUNK_SIZE] | .[].nullifier" "$nullifiers_file")

# abi encoded array of nullifiers
# mem prefix 
mem_prefix="$(printf "%064x" "32")"
array_length=$(printf "%064x" $(echo "$nullifiers" | wc -l))
echo "0x$mem_prefix$array_length$(echo "$nullifiers" | tr '\n' ',' | sed 's/0x//g' | sed 's/,//g')"