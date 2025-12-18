#!/usr/bin/env bash
set -euo pipefail

TARGET_SELECTOR="0x1e72049b"

echo "Searching for contracts whose ABI contains selector: $TARGET_SELECTOR"
echo

# loop through all JSON artifacts in out/
for artifact in $(find contracts/out -type f -name "*.json"); do
  # extract contract name from path: out/<file>/<contract>.json
  contract_name=$(basename "$artifact" .json)

  # run cast inspect
  inspect_output=$(cast inspect "$contract_name" abi 2>/dev/null || true)

  # check if selector appears
  if echo "$inspect_output" | grep -qi "$TARGET_SELECTOR"; then
    echo "🔥 Found selector in: $contract_name"
  fi
done
