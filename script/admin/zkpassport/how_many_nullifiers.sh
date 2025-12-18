#!/bin/bash
ROOT=$(git rev-parse --show-toplevel)

nullifiers_file="$ROOT/utilities/nullifier-extractor/nullifiers.json"

nullifiers_count=$(jq -r "length" "$nullifiers_file")
echo "0x$(printf "%064x" $nullifiers_count)"