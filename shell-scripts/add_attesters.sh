#!/bin/bash

# Script to add attesters from a JSON file using cast
# Usage: ./add_attesters.sh [OPTIONS]
#
# Options:
#   --rpc-url <url>           RPC endpoint URL (overrides RPC_URL env var)
#   --contract <address>      Staking contract address (auto-detected from chain ID if not provided)
#   --json <path>             Path to JSON file (default: ./attester_inputs.json)
#   --count <number>          Number of attesters to process (default: all)
#   --move-with-latest        Pass true for _moveWithLatestRollup parameter (default: false)
#   -h, --help                Show this help message
#
# Supported chains (auto-detection):
#   1        - Mainnet
#   11155111 - Sepolia
#   31337    - Dev (Anvil)

set -e

# Default values
JSON_FILE="$(dirname "$0")/attester_inputs.json"
MOVE_WITH_LATEST="false"
MAX_COUNT=""

# Function to display help
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        --contract)
            CONTRACT_ADDRESS="$2"
            shift 2
            ;;
        --json)
            JSON_FILE="$2"
            shift 2
            ;;
        --count)
            MAX_COUNT="$2"
            shift 2
            ;;
        --move-with-latest)
            MOVE_WITH_LATEST="true"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate required parameters
if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL must be set via --rpc-url flag or RPC_URL environment variable"
    exit 1
fi

# Auto-detect contract address if not provided
if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "Auto-detecting staking contract address from chain ID..."

    # Get chain ID from RPC
    CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
    CHAIN_ID_DEC=$(cast --to-dec "$CHAIN_ID" 2>/dev/null || echo "$CHAIN_ID")

    echo "  Chain ID: $CHAIN_ID_DEC"

    # Map chain ID to directory name
    case "$CHAIN_ID_DEC" in
        1)
            CONTRACTS_DIR="mainnet"
            ;;
        11155111)
            CONTRACTS_DIR="sepolia"
            ;;
        31337)
            CONTRACTS_DIR="dev"
            ;;
        *)
            echo "Error: Unsupported chain ID $CHAIN_ID_DEC"
            echo "Supported chains: 1 (mainnet), 11155111 (sepolia), 31337 (dev)"
            exit 1
            ;;
    esac

    # Construct path to contract addresses file
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    CONTRACTS_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/../.contracts/$CONTRACTS_DIR/contract_addresses.json"

    if [ ! -f "$CONTRACTS_FILE" ]; then
        echo "Error: Contract addresses file not found at $CONTRACTS_FILE"
        exit 1
    fi

    echo "  Loading addresses from: $CONTRACTS_FILE"

    # Read staking registry address from JSON
    CONTRACT_ADDRESS=$(jq -r '.rollupAddress' "$CONTRACTS_FILE")
    echo "  Staking Registry: $CONTRACT_ADDRESS"

    echo ""
fi

# Validate that we have the contract address
if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" = "null" ]; then
    echo "Error: --contract is required (or auto-detection failed)"
    echo "Run with --help for usage information"
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    exit 1
fi

# Check if cast is installed
if ! command -v cast &> /dev/null; then
    echo "Error: cast (foundry) is required but not installed"
    echo "Install from: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

echo "=================================================="
echo "Adding attesters to staking contract"
echo "=================================================="
echo "RPC URL:       $RPC_URL"
echo "Contract:      $CONTRACT_ADDRESS"
echo "JSON File:     $JSON_FILE"
echo "Move Latest:   $MOVE_WITH_LATEST"
echo "=================================================="
echo ""

# Function to get and display the entry queue length
get_rollup_stats() {
    local queue_length=$(cast call "$CONTRACT_ADDRESS" "getEntryQueueLength()(uint256)" --rpc-url "$RPC_URL")
    local active_attesters=$(cast call "$CONTRACT_ADDRESS" "getActiveAttesterCount()(uint256)" --rpc-url "$RPC_URL")
    echo "Entry queue length: $queue_length. Active attesters: $active_attesters."
}

# Function to flush the entry queue until empty
flush_till_empty() {
    echo ""
    echo "  Flushing entry queue until empty..."

    # Get current queue length
    QUEUE_LENGTH=$(cast call "$CONTRACT_ADDRESS" "getEntryQueueLength()(uint256)" --rpc-url "$RPC_URL")
    QUEUE_LENGTH_DEC=$(cast --to-dec "$QUEUE_LENGTH")

    if [ "$QUEUE_LENGTH_DEC" -eq 0 ]; then
        echo "  Queue is already empty, nothing to flush"
        echo ""
        return
    fi

    echo "  Queue length: $QUEUE_LENGTH_DEC"

    # Calculate epoch time dynamically (slot_duration * epoch_duration)
    if [ -z "$EPOCH_TIME" ]; then
        SLOT_DURATION=$(cast call "$CONTRACT_ADDRESS" "getSlotDuration()(uint256)" --rpc-url "$RPC_URL")
        SLOT_DURATION_DEC=$(cast --to-dec "$SLOT_DURATION")
        EPOCH_DURATION=$(cast call "$CONTRACT_ADDRESS" "getEpochDuration()(uint256)" --rpc-url "$RPC_URL")
        EPOCH_DURATION_DEC=$(cast --to-dec "$EPOCH_DURATION")
        EPOCH_TIME=$((SLOT_DURATION_DEC * EPOCH_DURATION_DEC))
    fi

    # Keep flushing until queue is empty
    while [ "$QUEUE_LENGTH_DEC" -gt 0 ]; do
        # Check available flushes
        AVAILABLE_FLUSHES=$(cast call "$CONTRACT_ADDRESS" "getAvailableValidatorFlushes()(uint256)" --rpc-url "$RPC_URL")
        AVAILABLE_FLUSHES_DEC=$(cast --to-dec "$AVAILABLE_FLUSHES")

        # If no flushes available, jump to next epoch
        if [ "$AVAILABLE_FLUSHES_DEC" -eq 0 ]; then
            echo "  No flushes available, jumping to next epoch..."
            cast rpc evm_increaseTime "$EPOCH_TIME" --rpc-url "$RPC_URL" > /dev/null
            cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
            echo "  ✓ Advanced time by $EPOCH_TIME seconds"
            continue
        fi

        # Flush as many as we can (min of available, queue length, and max 16)
        FLUSH_COUNT=$AVAILABLE_FLUSHES_DEC
        if [ "$QUEUE_LENGTH_DEC" -lt "$FLUSH_COUNT" ]; then
            FLUSH_COUNT=$QUEUE_LENGTH_DEC
        fi
        if [ "$FLUSH_COUNT" -gt 16 ]; then
            FLUSH_COUNT=16
        fi

        echo "  Flushing $FLUSH_COUNT attesters (available: $AVAILABLE_FLUSHES_DEC)..."

        cast send "$CONTRACT_ADDRESS" \
            "flushEntryQueue(uint256)" \
            "$FLUSH_COUNT" \
            --private-key "$DEPLOYER_PRIVATE_KEY" \
            --async \
            --rpc-url "$RPC_URL" > /dev/null

        if [ $? -eq 0 ]; then
            echo "  ✓ Flushed $FLUSH_COUNT attesters"
        else
            echo "  ✗ Failed to flush"
            break
        fi

        # Update queue length
        QUEUE_LENGTH=$(cast call "$CONTRACT_ADDRESS" "getEntryQueueLength()(uint256)" --rpc-url "$RPC_URL")
        QUEUE_LENGTH_DEC=$(cast --to-dec "$QUEUE_LENGTH")
        echo "  Remaining in queue: $QUEUE_LENGTH_DEC"
    done

    echo "  ✓ Queue fully flushed"
    echo ""
}

# Function to setup environment (check balances, mint if needed, approve)
setup_deployer() {
    echo "Setting up deployer environment..."
    echo ""

    # Get the deployer (first attester) from JSON
    DEPLOYER=$(jq -r '.[0].attester_address' "$JSON_FILE")
    DEPLOYER_PRIVATE_KEY=$(jq -r '.[0].attester_private_key' "$JSON_FILE")

    echo "  Deployer: $DEPLOYER"

    # Get token address from staking contract
    TOKEN_ADDRESS=$(cast call "$CONTRACT_ADDRESS" "getStakingAsset()(address)" --rpc-url "$RPC_URL")
    echo "  Token: $TOKEN_ADDRESS"

    # Get activation threshold (amount needed per attester) - convert from hex to decimal
    ACTIVATION_THRESHOLD=$(cast call "$CONTRACT_ADDRESS" "getActivationThreshold()" --rpc-url "$RPC_URL")
    ACTIVATION_THRESHOLD_DEC=$(cast --to-dec "$ACTIVATION_THRESHOLD")
    ACTIVATION_THRESHOLD_HUMAN=$(cast --from-wei "$ACTIVATION_THRESHOLD_DEC")
    echo "  Activation threshold: $ACTIVATION_THRESHOLD_HUMAN tokens ($ACTIVATION_THRESHOLD_DEC wei)"

    # Calculate total needed (1000 attesters worth) using Python for big number math
    TOTAL_NEEDED=$(python3 -c "print($ACTIVATION_THRESHOLD_DEC * 1000)")
    TOTAL_NEEDED_HUMAN=$(cast --from-wei "$TOTAL_NEEDED")
    echo "  Total tokens needed: $TOTAL_NEEDED_HUMAN tokens ($TOTAL_NEEDED wei)"

    # Ensure deployer has ETH for gas
    echo "  Setting deployer ETH balance to 100 ETH..."
    cast rpc anvil_setBalance "$DEPLOYER" "0x56BC75E2D63100000" --rpc-url "$RPC_URL" > /dev/null
    echo "  ✓ Deployer funded with ETH"

    # Check current balance - convert from hex to decimal
    CURRENT_BALANCE=$(cast call "$TOKEN_ADDRESS" "balanceOf(address)" "$DEPLOYER" --rpc-url "$RPC_URL")
    CURRENT_BALANCE_DEC=$(cast --to-dec "$CURRENT_BALANCE")
    CURRENT_BALANCE_HUMAN=$(cast --from-wei "$CURRENT_BALANCE_DEC")
    echo "  Current token balance: $CURRENT_BALANCE_HUMAN tokens ($CURRENT_BALANCE_DEC wei)"

    # Check if we need to mint more (using Python for comparison)
    NEEDS_MINT=$(python3 -c "print(1 if $CURRENT_BALANCE_DEC < $TOTAL_NEEDED else 0)")

    if [ "$NEEDS_MINT" -eq 1 ]; then
        MINT_AMOUNT=$(python3 -c "print($TOTAL_NEEDED - $CURRENT_BALANCE_DEC)")
        MINT_AMOUNT_HUMAN=$(cast --from-wei "$MINT_AMOUNT")
        echo "  Need to mint: $MINT_AMOUNT_HUMAN tokens ($MINT_AMOUNT wei)"

        # Get token owner from the token contract
        TOKEN_OWNER=$(cast call "$TOKEN_ADDRESS" "owner()(address)" --rpc-url "$RPC_URL")
        echo "  Detected token owner: $TOKEN_OWNER"

        echo "  Impersonating $TOKEN_OWNER to mint tokens..."
        cast rpc anvil_impersonateAccount "$TOKEN_OWNER" --rpc-url "$RPC_URL" > /dev/null

        cast rpc anvil_setBalance "$TOKEN_OWNER" "0x56BC75E2D63100000" --rpc-url "$RPC_URL" > /dev/null

        cast send "$TOKEN_ADDRESS" "mint(address,uint256)" "$DEPLOYER" "$MINT_AMOUNT" \
            --from "$TOKEN_OWNER" \
            --rpc-url "$RPC_URL" \
            --unlocked \
            --quiet

        cast rpc anvil_stopImpersonatingAccount "$TOKEN_OWNER" --rpc-url "$RPC_URL" > /dev/null
        echo "  ✓ Minted $MINT_AMOUNT_HUMAN tokens"
    else
        echo "  ✓ Sufficient token balance"
    fi

    # Check current allowance - convert from hex to decimal
    CURRENT_ALLOWANCE=$(cast call "$TOKEN_ADDRESS" "allowance(address,address)" "$DEPLOYER" "$CONTRACT_ADDRESS" --rpc-url "$RPC_URL")
    CURRENT_ALLOWANCE_DEC=$(cast --to-dec "$CURRENT_ALLOWANCE")
    CURRENT_ALLOWANCE_HUMAN=$(cast --from-wei "$CURRENT_ALLOWANCE_DEC")
    echo "  Current allowance: $CURRENT_ALLOWANCE_HUMAN tokens ($CURRENT_ALLOWANCE_DEC wei)"

    # Approve if needed (using Python for comparison)
    NEEDS_APPROVAL=$(python3 -c "print(1 if $CURRENT_ALLOWANCE_DEC < $TOTAL_NEEDED else 0)")
    if [ "$NEEDS_APPROVAL" -eq 1 ]; then
        echo "  Approving $CONTRACT_ADDRESS to spend $TOTAL_NEEDED_HUMAN tokens..."
        cast send "$TOKEN_ADDRESS" "approve(address,uint256)" "$CONTRACT_ADDRESS" "$TOTAL_NEEDED" \
            --from "$DEPLOYER" \
            --private-key "$DEPLOYER_PRIVATE_KEY" \
            --rpc-url "$RPC_URL" \
            --quiet
        echo "  ✓ Approved"
    else
        echo "  ✓ Sufficient allowance"
    fi

    echo ""
}

# Function to add a single attester
add_attester() {
    local attester_json="$1"
    local count="$2"
    local total="$3"

    echo "Processing attester $count/$total..."

    # Extract data from JSON object
    ATTESTER_ADDRESS=$(echo "$attester_json" | jq -r '.attester_address')
    ATTESTER_PRIVATE_KEY=$(echo "$attester_json" | jq -r '.attester_private_key')

    # G1 point (publicKeyInG1)
    G1_X=$(echo "$attester_json" | jq -r '.publicKeyInG1.x')
    G1_Y=$(echo "$attester_json" | jq -r '.publicKeyInG1.y')

    # G2 point (publicKeyInG2)
    G2_X0=$(echo "$attester_json" | jq -r '.publicKeyInG2.x0')
    G2_X1=$(echo "$attester_json" | jq -r '.publicKeyInG2.x1')
    G2_Y0=$(echo "$attester_json" | jq -r '.publicKeyInG2.y0')
    G2_Y1=$(echo "$attester_json" | jq -r '.publicKeyInG2.y1')

    # Proof of possession (G1 point)
    POP_X=$(echo "$attester_json" | jq -r '.proofOfPossession.x')
    POP_Y=$(echo "$attester_json" | jq -r '.proofOfPossession.y')

    echo "  Attester: $ATTESTER_ADDRESS"

    # Build the cast command with proper struct encoding
    # The deposit function signature is:
    # deposit(address _attester, address _withdrawer, (uint256,uint256) _publicKeyInG1, (uint256,uint256,uint256,uint256) _publicKeyInG2, (uint256,uint256) _proofOfPossession, bool _moveWithLatestRollup)

    # Using attester address as withdrawer (same address)
    WITHDRAWER="$ATTESTER_ADDRESS"

    # Use DEPLOYER's key for all deposit transactions
    cast send "$CONTRACT_ADDRESS" \
        "deposit(address,address,(uint256,uint256),(uint256,uint256,uint256,uint256),(uint256,uint256),bool)" \
        "$ATTESTER_ADDRESS" \
        "$WITHDRAWER" \
        "($G1_X,$G1_Y)" \
        "($G2_X0,$G2_X1,$G2_Y0,$G2_Y1)" \
        "($POP_X,$POP_Y)" \
        "$MOVE_WITH_LATEST" \
        --rpc-url "$RPC_URL" \
        --async \
        --private-key "$DEPLOYER_PRIVATE_KEY" > /dev/null

    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully processed attester $count/$total"
    else
        echo "  ✗ Failed to process attester $count/$total"
        echo "  Press Enter to continue or Ctrl+C to abort..."
        read
    fi

    echo ""
}

# Count total attesters
TOTAL=$(jq 'length' "$JSON_FILE")

# Apply max count if specified
if [ -n "$MAX_COUNT" ]; then
    if [ "$MAX_COUNT" -lt "$TOTAL" ]; then
        TOTAL=$MAX_COUNT
    fi
fi

echo "Found $TOTAL attesters to add"
echo ""

# Setup deployer (mint tokens and approve if needed)
setup_deployer

get_rollup_stats
echo ""

# Process each attester using jq streaming (limit to MAX_COUNT if specified)
count=1
for attester_json in $(jq -c '.[]' "$JSON_FILE"); do
    if [ -n "$MAX_COUNT" ] && [ "$count" -gt "$MAX_COUNT" ]; then
        break
    fi
    add_attester "$attester_json" "$count" "$TOTAL"

    count=$((count + 1))
done

# Final flush to empty any remaining in queue
flush_till_empty

echo "=================================================="
echo "Finished processing all attesters"
echo "=================================================="
echo ""
get_rollup_stats
