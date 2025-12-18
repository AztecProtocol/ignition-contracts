#!/bin/bash

# Script to signal governance proposals using attesters from JSON file
# Usage: ./signal_governance.sh [OPTIONS]
#
# Options:
#   --rpc-url <url>           RPC endpoint URL (overrides RPC_URL env var)
#   --rollup <address>        Rollup contract address (auto-detected from chain ID if not provided)
#   --empire <address>        Empire governance contract address (auto-detected from chain ID if not provided)
#   --payload <address>       Payload contract address to signal for (required)
#   --json <path>             Path to JSON file with attesters (default: ./attester_inputs.json)
#   --required-votes <num>    Number of votes required (default: keep signaling until user stops)
#   --log-every <num>         Log signal count every N signals (default: 10)
#   -h, --help                Show this help message
#
# Supported chains (auto-detection):
#   1        - Mainnet
#   11155111 - Sepolia
#   31337    - Dev (Anvil)

set -e

# Default values
JSON_FILE="$(dirname "$0")/attester_inputs.json"
REQUIRED_VOTES=""
LOG_FREQUENCY=10

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
        --rollup)
            ROLLUP_ADDRESS="$2"
            shift 2
            ;;
        --empire)
            EMPIRE_ADDRESS="$2"
            shift 2
            ;;
        --payload)
            PAYLOAD_ADDRESS="$2"
            shift 2
            ;;
        --json)
            JSON_FILE="$2"
            shift 2
            ;;
        --required-votes)
            REQUIRED_VOTES="$2"
            shift 2
            ;;
        --log-every)
            LOG_FREQUENCY="$2"
            shift 2
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

# Auto-detect contract addresses if not provided
if [ -z "$ROLLUP_ADDRESS" ] || [ -z "$EMPIRE_ADDRESS" ]; then
    echo "Auto-detecting contract addresses from chain ID..."

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

    # Read addresses from JSON if not already provided
    if [ -z "$ROLLUP_ADDRESS" ]; then
        ROLLUP_ADDRESS=$(jq -r '.rollupAddress' "$CONTRACTS_FILE")
        echo "  Rollup: $ROLLUP_ADDRESS"
    fi

    if [ -z "$EMPIRE_ADDRESS" ]; then
        EMPIRE_ADDRESS=$(jq -r '.governanceProposerAddress' "$CONTRACTS_FILE")
        echo "  Empire: $EMPIRE_ADDRESS"
    fi

    if [ -z "$PAYLOAD_ADDRESS" ]; then
        echo "Error: --payload is required"
        exit 1
    fi

    echo ""
fi

# Validate that we have all required addresses
if [ -z "$ROLLUP_ADDRESS" ] || [ "$ROLLUP_ADDRESS" = "null" ]; then
    echo "Error: --rollup is required (or auto-detection failed)"
    echo "Run with --help for usage information"
    exit 1
fi

if [ -z "$EMPIRE_ADDRESS" ] || [ "$EMPIRE_ADDRESS" = "null" ]; then
    echo "Error: --empire is required (or auto-detection failed)"
    echo "Run with --help for usage information"
    exit 1
fi

if [ -z "$PAYLOAD_ADDRESS" ]; then
    echo "Error: --payload is required"
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
echo "Signaling governance proposal"
echo "=================================================="
echo "RPC URL:       $RPC_URL"
echo "Rollup:        $ROLLUP_ADDRESS"
echo "Empire:        $EMPIRE_ADDRESS"
echo "Payload:       $PAYLOAD_ADDRESS"
echo "JSON File:     $JSON_FILE"
if [ -n "$REQUIRED_VOTES" ]; then
    echo "Target Votes:  $REQUIRED_VOTES"
fi
echo "=================================================="
echo ""

# Get deployer (first attester) for submitting transactions
DEPLOYER=$(jq -r '.[0].attester_address' "$JSON_FILE")
DEPLOYER_PRIVATE_KEY=$(jq -r '.[0].attester_private_key' "$JSON_FILE")
echo "Deployer: $DEPLOYER"
echo ""

# Ensure deployer has ETH for gas
echo "Setting deployer ETH balance to 100 ETH..."
cast rpc anvil_setBalance "$DEPLOYER" "0x56BC75E2D63100000" --rpc-url "$RPC_URL" > /dev/null
echo "✓ Deployer funded with ETH"
echo ""

# Get immutable parameters - instance is the rollup
INSTANCE="$ROLLUP_ADDRESS"

# Get slot duration from rollup
SLOT_DURATION=$(cast call "$INSTANCE" "getSlotDuration()(uint256)" --rpc-url "$RPC_URL")
SLOT_DURATION_DEC=$(cast --to-dec "$SLOT_DURATION")

# Get epoch duration from rollup
EPOCH_DURATION=$(cast call "$INSTANCE" "getEpochDuration()(uint256)" --rpc-url "$RPC_URL")
EPOCH_DURATION_DEC=$(cast --to-dec "$EPOCH_DURATION")
EPOCH_TIME=$((SLOT_DURATION_DEC * EPOCH_DURATION_DEC))

# Get QUORUM_SIZE to know target
QUORUM_SIZE=$(cast call "$EMPIRE_ADDRESS" "QUORUM_SIZE()(uint256)" --rpc-url "$RPC_URL")
QUORUM_SIZE_DEC=$(cast --to-dec "$QUORUM_SIZE")
echo "Quorum size: $QUORUM_SIZE_DEC signals required"
echo "Slot duration: $SLOT_DURATION_DEC seconds"
echo "Epoch duration: $EPOCH_DURATION_DEC slots ($EPOCH_TIME seconds)"
echo ""

# If no required votes specified, use QUORUM_SIZE
if [ -z "$REQUIRED_VOTES" ]; then
    REQUIRED_VOTES=$QUORUM_SIZE_DEC
    echo "Target votes: $REQUIRED_VOTES (using QUORUM_SIZE)"
    echo ""
fi

# Function to get current signal count and round info
get_signal_count_and_round() {
    local current_slot=$(cast call "$INSTANCE" "getCurrentSlot()(uint256)" --rpc-url "$RPC_URL")
    local current_slot_dec=$(cast --to-dec "$current_slot")
    local round=$(cast call "$EMPIRE_ADDRESS" "computeRound(uint256)(uint256)" "$current_slot_dec" --rpc-url "$RPC_URL")
    local round_dec=$(cast --to-dec "$round")

    local signal_count=$(cast call "$EMPIRE_ADDRESS" "signalCount(address,uint256,address)(uint256)" "$INSTANCE" "$round_dec" "$PAYLOAD_ADDRESS" --rpc-url "$RPC_URL")
    local signal_count_dec=$(cast --to-dec "$signal_count")

    echo "$signal_count_dec $round_dec"
}

# Simpler function for just signal count (for final check)
get_signal_count() {
    local result=$(get_signal_count_and_round)
    echo "${result%% *}"
}

# Function to find attester by address
find_attester_private_key() {
    local address=$1
    local private_key=$(jq -r ".[] | select(.attester_address == \"$address\") | .attester_private_key" "$JSON_FILE")

    # Pad private key to 66 characters (0x + 64 hex digits) if needed
    if [ -n "$private_key" ] && [ "$private_key" != "null" ]; then
        # Remove 0x prefix
        local key_without_prefix="${private_key#0x}"
        # Pad to 64 characters with leading zeros
        local padded_key=$(printf "0x%064s" "$key_without_prefix" | tr ' ' '0')
        echo "$padded_key"
    else
        echo "$private_key"
    fi
}

# Function to signal with a specific proposer
signal() {
    local proposer=$1
    local target_slot=$2
    local count=$3

    echo "Signal #$count - Proposer: $proposer"

    # Find the private key for this proposer
    PROPOSER_PRIVATE_KEY=$(find_attester_private_key "$proposer")

    if [ -z "$PROPOSER_PRIVATE_KEY" ] || [ "$PROPOSER_PRIVATE_KEY" = "null" ]; then
        echo "  ✗ Proposer not found in JSON file, skipping..."
        return 1
    fi

    # Use the TARGET_SLOT_DEC that was calculated in the main loop
    # This is the current slot at the current timestamp

    # Get the signature digest for the target slot
    local digest=$(cast call "$EMPIRE_ADDRESS" "getSignalSignatureDigest(address,uint256)(bytes32)" "$PAYLOAD_ADDRESS" "$target_slot" --rpc-url "$RPC_URL")

    # Sign the digest with the proposer's private key
    local signature=$(cast wallet sign --private-key "$PROPOSER_PRIVATE_KEY" "$digest" --no-hash)

    # Extract v, r, s from signature
    local v="0x${signature:130:2}"
    local r="0x${signature:2:64}"
    local s="0x${signature:66:64}"

    echo "  Submitting signal with signature..."

    # Call signalWithSig with --async for speed (don't wait for receipt)
    local result=$(cast send "$EMPIRE_ADDRESS" \
        "signalWithSig(address,(uint8,bytes32,bytes32))" \
        "$PAYLOAD_ADDRESS" \
        "($v,$r,$s)" \
        --private-key "$DEPLOYER_PRIVATE_KEY" \
        --rpc-url "$RPC_URL" \
        --async 2>&1)

    if [ $? -eq 0 ]; then
        echo "  ✓ Signal submitted (tx hash: ${result:0:10}...)"
        return 0
    else
        echo "  ✗ Failed to submit signal: $result"
        return 1
    fi
}

# Main loop
signal_count=0
iteration=1

# Get initial current slot
echo "Getting current slot..."
CURRENT_SLOT=$(cast call "$INSTANCE" "getCurrentSlot()(uint256)" --rpc-url "$RPC_URL" 2>&1)
if [ $? -ne 0 ]; then
    echo "Error calling getCurrentSlot(): $CURRENT_SLOT"
    exit 1
fi
if [ -z "$CURRENT_SLOT" ] || [ "$CURRENT_SLOT" = "0x" ]; then
    echo "Error: getCurrentSlot() returned empty or invalid value: '$CURRENT_SLOT'"
    exit 1
fi

# Check if it's already decimal (no 0x prefix) or hex
if [[ "$CURRENT_SLOT" == 0x* ]]; then
    CURRENT_SLOT_DEC=$(cast --to-dec "$CURRENT_SLOT")
else
    CURRENT_SLOT_DEC=$CURRENT_SLOT
fi

if [ -z "$CURRENT_SLOT_DEC" ]; then
    echo "Error converting slot to decimal. Raw value: '$CURRENT_SLOT'"
    exit 1
fi
echo "Current slot: $CURRENT_SLOT_DEC"
echo ""

CURRENT_SLOT_DEC=$((CURRENT_SLOT_DEC + 1))

# Jump 3 epochs into the future to ensure we're past any initialization issues
echo "Advancing 3 epochs to ensure proposer system is ready..."
CURRENT_SLOT_DEC=$((CURRENT_SLOT_DEC + 3 * EPOCH_DURATION_DEC))
echo "Jumped to slot: $CURRENT_SLOT_DEC"
echo ""

# Get the exact timestamp for this slot
SLOT_TIMESTAMP=$(cast call "$INSTANCE" "getTimestampForSlot(uint256)" "$CURRENT_SLOT_DEC" --rpc-url "$RPC_URL")
SLOT_TIMESTAMP_DEC=$(cast --to-dec "$SLOT_TIMESTAMP")

while true; do
    # Set blockchain time to exactly the start of the next slot
    if [ "$iteration" -gt 1 ]; then
        CURRENT_SLOT_DEC=$((CURRENT_SLOT_DEC + 1))
        SLOT_TIMESTAMP_DEC=$((SLOT_TIMESTAMP_DEC + SLOT_DURATION_DEC))
    fi

    # Set the blockchain time to exactly this slot's timestamp
    echo "  Setting time to slot $CURRENT_SLOT_DEC (timestamp: $SLOT_TIMESTAMP_DEC)..."
    cast rpc evm_setNextBlockTimestamp "$SLOT_TIMESTAMP_DEC" --rpc-url "$RPC_URL" > /dev/null

    ## RELY ON SLOTS TIME > 12 seconds.

    # Get current proposer for this slot
    CURRENT_PROPOSER=$(cast call "$ROLLUP_ADDRESS" "getProposerAt(uint256)(address)" "$SLOT_TIMESTAMP_DEC" --rpc-url "$RPC_URL")

    echo "Current proposer: $CURRENT_PROPOSER"

    if signal "$CURRENT_PROPOSER" "$CURRENT_SLOT_DEC" "$iteration"; then
        signal_count=$((signal_count + 1))

        # Check signal count periodically for efficiency
        if [ $((signal_count % LOG_FREQUENCY)) -eq 0 ]; then
            # Get updated signal count and round from contract
            RESULT=$(get_signal_count_and_round)
            ACTUAL_SIGNALS="${RESULT%% *}"
            ROUND_NUM="${RESULT##* }"

            echo ""
            echo "  ==== Status Update ===="
            echo "  Signals submitted: $signal_count"
            echo "  Signals on leader this round: $ACTUAL_SIGNALS"
            echo "  Round: $ROUND_NUM"
            echo "  Payload: $PAYLOAD_ADDRESS"
            echo "  ======================"
            echo ""

            # Check if we've reached the required votes
            if [ -n "$REQUIRED_VOTES" ] && [ "$ACTUAL_SIGNALS" -ge "$REQUIRED_VOTES" ]; then
                echo "=================================================="
                echo "Reached required votes ($REQUIRED_VOTES)"
                echo "=================================================="
                break
            fi
        fi
    fi

    iteration=$((iteration + 1))

    # If no required votes set, ask user if they want to continue after every 50 iterations
    if [ -z "$REQUIRED_VOTES" ] && [ $((iteration % 50)) -eq 0 ]; then
        RESULT=$(get_signal_count_and_round)
        ACTUAL_SIGNALS="${RESULT%% *}"
        echo "Current signals: $ACTUAL_SIGNALS"
        echo "Continue signaling? (y/n)"
        read -r response
        if [ "$response" != "y" ]; then
            break
        fi
    fi
done

echo ""
echo "=================================================="
echo "Finished signaling"
echo "=================================================="
echo "Total signals submitted: $signal_count"
FINAL_SIGNALS=$(get_signal_count)
echo "Final signal count for payload: $FINAL_SIGNALS"
