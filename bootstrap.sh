#!/bin/bash
set -eo pipefail

ROOT=$(git rev-parse --show-toplevel)

function build() {
    cd $ROOT
    FOUNDRY_PROFILE="production" forge build

    cd $ROOT/test/integration/token-laucher-address-miner
    cargo build --release
    cd $ROOT
}

function test() {
    cd $ROOT
    forge test
    cd $ROOT
}

function coverage() {
    cd $ROOT
    forge coverage --no-match-coverage "test|script|mock|generated|core|periphery"
    cd $ROOT
}

# If dry run is enabled, we don't broadcast the transactions
if [ "$DRY_RUN" = "true" ]; then
    export BROADCAST_ARGS=""
else
    export BROADCAST_ARGS="--broadcast --slow --non-interactive"
fi

export DEPLOYER_ADDRESS=$DEPLOYER_ADDRESS
export DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY
export TESTING_FOUNDATION_ADDRESS=${TESTING_FOUNDATION_ADDRESS:-"0x70997970C51812dc3A010C7d01b50e0d17dc79C8"}
export TESTING_FOUNDATION_PRIVATE_KEY=${TESTING_FOUNDATION_PRIVATE_KEY:-"0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"}
export RAW_PRIVATE_KEYS=${RAW_PRIVATE_KEYS:-"$DEPLOYER_PRIVATE_KEY $TESTING_FOUNDATION_PRIVATE_KEY"}

export TESTNET_MINTER_KEY=${TESTNET_MINTER_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
export AUCTION_START_BLOCK=${AUCTION_START_BLOCK:-200}
export AUCTION_DURATION=${AUCTION_DURATION:-200}
export MINT_SOULBOUND_NFTS=${MINT_SOULBOUND_NFTS:-0}
export ANVIL6=0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e

# Depends on deploy_twap_auction being called to populate data
function generate_test_auction_data() {
    export TWAP_AUCTION_ADDRESS=$(cat $DEPLOYMENTS_DIR/collective-l1-deployment-$CHAIN_ID.json | jq -r '.twapAuction')
    export SOULBOUND_ADDRESS=$(cat $DEPLOYMENTS_DIR/collective-l1-deployment-$CHAIN_ID.json | jq -r '.soulboundToken')

    # Get current block number from rpc
    CURRENT_BLOCK=$(cast block-number --rpc-url $RPC_URL)
    BLOCKS_TO_ROLL=$(expr $AUCTION_START_BLOCK - $CURRENT_BLOCK)
    $ROOT/shell-scripts/roll.sh $BLOCKS_TO_ROLL

    # Generate auction data
    cd $ROOT/script/
    echo "Running script to generate test auction data"
    forge script GenerateAuctionData.sol:GenerateAuctionData \
        --rpc-url $RPC_URL \
        --private-key $DEPLOYER_PRIVATE_KEY \
        $BROADCAST_ARGS -vvv

    cd $ROOT
}

function fund_contracts() {
    cd $ROOT

    export STAKING_ASSET_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.stakingAssetAddress')
    export GENESIS_SEQUENCER_SALE_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.genesisSequencerSale')
    export VIRTUAL_AZTEC_TOKEN_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.virtualAztecToken')
    export AUCTION_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.twapAuction')

    if [ "$DEPLOY_AZTEC_CONTRACTS" = "true" ]; then
        PRIVATE_KEY="$DEPLOYER_PRIVATE_KEY"
    else
        PRIVATE_KEY="$TESTNET_MINTER_KEY"
    fi


    cd $ROOT/script/deploy

    forge script utilities/FundContracts.s.sol:FundContracts \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        $BROADCAST_ARGS -vv

    cd $ROOT
}

function process_merkle_tree() {
    cd $ROOT
    yarn
    yarn process-merkle-tree
    cd $ROOT
}

function fund_local_account() {
    # If the .localacc file exists, fund the account
    if [ -f $ROOT/.localacc ]; then
        local_account_address=$(cat $ROOT/.localacc)
        echo "Funding local account $local_account_address"
        # Fund the local account
        cast send --rpc-url http://localhost:8545 --private-key $DEPLOYER_PRIVATE_KEY --value 1000000000000000000000 "$local_account_address"
        echo "Funded local account $local_account_address"
    else
        echo "No local account found, skipping funding"
    fi
}

function mint_eth_for_account() {
    local account_address=$1

    echo "Minting ETH for account $account_address"
    cast rpc anvil_setBalance "$account_address" "0x56BC75E2D63100000" --rpc-url "$RPC_URL" > /dev/null
    echo "Minted ETH for account $account_address"
}

function generate_random_tile_id() {
    grid_id=${1:-1}
    width=${2:-44}
    height=${3:-29}
    node -p "Number(BigInt($grid_id) << 32n | BigInt((Math.random() * $width) << 16) | BigInt(Math.random() * $height | 0))"
}

function mint_with_retry() {
    local address=$1
    local token_id=$2
    local grid_id=${3:-2}
    local rows=${4:-53}
    local cols=${5:-44}
    local max_retries=${6:-10}
    local attempt=1

    has_minted=$(cast call $SOULBOUND_ADDRESS "hasMinted(address)" $address)

    # Check if result is non-zero (0x01 or any non-zero value)
    if [ "$has_minted" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
        echo "Already minted, exiting early"
        return 0
    fi

    while [ $attempt -le $max_retries ]; do
        tile_id=$(generate_random_tile_id $grid_id $rows $cols)
        echo "Attempt $attempt/$max_retries: Minting NFT with tile_id $tile_id for $address"

        if cast send --rpc-url $RPC_URL \
            --private-key $DEPLOYER_PRIVATE_KEY \
            $SOULBOUND_ADDRESS \
            "adminMint(address,uint8,uint256)" \
            $address $token_id $tile_id 2>&1; then
            echo "Successfully minted NFT for $address with tile_id $tile_id"
            return 0
        else
            echo "Failed to mint (likely duplicate tile_id). Retrying..."
            attempt=$((attempt + 1))
        fi
    done

    echo "Error: Failed to mint NFT for $address after $max_retries attempts"
    return 1
}

function mint_soulbound_nfts() {
    cd $ROOT
    export SOULBOUND_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.soulboundToken')

    echo "Minting soulbound NFT for genesis"
    GENESIS_SEQUENCER_ADDRESSES=$(cat merkle-tree/input/genesis_sequencer_whitelist.csv)
    for address in $GENESIS_SEQUENCER_ADDRESSES; do
        echo "Minting genesis NFT for $address"
        mint_with_retry $address 0 || exit 1
    done

    echo "Minting soulbound NFTs for contributors"
    CONTRIBUTOR_ADDRESSES=$(cat merkle-tree/input/contributor_whitelist.csv)
    for address in $CONTRIBUTOR_ADDRESSES; do
        echo "Minting contributor NFT for $address"
        mint_with_retry $address 1 || exit 1
    done
}

function admin_mint_tiles() {
    local grid_id=${1}
    local count=${2}

    if [ -z "$grid_id" ] || [ -z "$count" ]; then
        echo "Usage: $0 admin-mint-tiles <gridId> <count>"
        echo "  gridId: The grid ID to mint tiles for"
        echo "  count: Number of tiles to mint"
        exit 1
    fi

    cd $ROOT

    export CONTRACTS_OUTPUT_FILE=".contracts/dev/contract_addresses.json"
    export SOULBOUND_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.soulboundToken')
    export RPC_URL=${RPC_URL:-http://127.0.0.1:8545}

    # Read grid dimensions from grids.json
    local grid_info=$(cat backends/nft-grid/grids.json | jq ".[] | select(.id == $grid_id)")

    if [ -z "$grid_info" ]; then
        echo "Error: Grid with ID $grid_id not found in backends/nft-grid/grids.json"
        exit 1
    fi

    local columns=$(echo "$grid_info" | jq -r '.columns')
    local rows=$(echo "$grid_info" | jq -r '.rows')

    echo "Minting $count admin tiles for grid $grid_id (${columns}x${rows})"
    echo "Using address: $DEPLOYER_ADDRESS"

    local minted=0

    while [ $minted -lt $count ]; do
        addr=$(cast w n --json | jq -r '.[0] | .address')
        mint_with_retry $addr 2 $grid_id $columns $rows
        minted=$((minted + 1))
    done

    echo "Successfully minted all $count tiles"
}

function dev() {
    # For local development, will:
    # 1. Start an anvil node
    # 2. Deploy the multicall contract
    # 3. Deploy the permit2 contract
    # 4. Fund the local accounts
    # 5. Deploy zk passport verifiers and registry
    #
    # 6. Call the deployment flow       <-- this is where we create all non test things!
    #
    # 7. Optionally mint soul-bound NFT's for every address in merkle trees
    # 8. Generate auction test data
    # 9. Keep anvil running - user must manually close it

    # Script to bootstrap a local development environment to test against.
    cd $ROOT
    mkdir -p .contracts/dev
    export CONTRACTS_OUTPUT_FILE="$ROOT/.contracts/dev/contract_addresses.json"

    mkdir -p deployments
    # Get the addresses of the deployed contracts from the contracts output file
    export DEPLOYMENTS_DIR=$ROOT/deployments

    export RPC_URL=http://localhost:8545
    export CHAIN_ID=31337

    anvil -p 8545 --host 0.0.0.0 -q --chain-id $CHAIN_ID &
    ANVIL_PID=$!
    trap "echo 'Stopping anvil...'; kill $ANVIL_PID" EXIT INT TERM
    echo "Running anvil node on port 8545"

    export CONFIGURATION_VARIANT=${CONFIGURATION_VARIANT:-"DRESS_REHEARSAL"}
    export CHAIN_ENVIRONMENT_VARIANT="FRESH_NETWORK"

    local max_attempts=30
    local attempt=1

    echo "Waiting for Anvil to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if cast block-number &> /dev/null; then
            echo "Anvil is ready!"
            break
        fi
        sleep 1
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        echo "ERROR: Anvil did not become ready in time"
        return 1
    fi

    echo "Deploying multicall"
    local multicall_deployer=0x05f32b3cc3888453ff71b01135b34ff8e41263f2
    cast send --value 1ether --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL $multicall_deployer
    local tx=0xf90f538085174876e800830f42408080b90f00608060405234801561001057600080fd5b50610ee0806100206000396000f3fe6080604052600436106100f35760003560e01c80634d2301cc1161008a578063a8b0574e11610059578063a8b0574e1461025a578063bce38bd714610275578063c3077fa914610288578063ee82ac5e1461029b57600080fd5b80634d2301cc146101ec57806372425d9d1461022157806382ad56cb1461023457806386d516e81461024757600080fd5b80633408e470116100c65780633408e47014610191578063399542e9146101a45780633e64a696146101c657806342cbb15c146101d957600080fd5b80630f28c97d146100f8578063174dea711461011a578063252dba421461013a57806327e86d6e1461015b575b600080fd5b34801561010457600080fd5b50425b6040519081526020015b60405180910390f35b61012d610128366004610a85565b6102ba565b6040516101119190610bbe565b61014d610148366004610a85565b6104ef565b604051610111929190610bd8565b34801561016757600080fd5b50437fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0140610107565b34801561019d57600080fd5b5046610107565b6101b76101b2366004610c60565b610690565b60405161011193929190610cba565b3480156101d257600080fd5b5048610107565b3480156101e557600080fd5b5043610107565b3480156101f857600080fd5b50610107610207366004610ce2565b73ffffffffffffffffffffffffffffffffffffffff163190565b34801561022d57600080fd5b5044610107565b61012d610242366004610a85565b6106ab565b34801561025357600080fd5b5045610107565b34801561026657600080fd5b50604051418152602001610111565b61012d610283366004610c60565b61085a565b6101b7610296366004610a85565b610a1a565b3480156102a757600080fd5b506101076102b6366004610d18565b4090565b60606000828067ffffffffffffffff8111156102d8576102d8610d31565b60405190808252806020026020018201604052801561031e57816020015b6040805180820190915260008152606060208201528152602001906001900390816102f65790505b5092503660005b8281101561047757600085828151811061034157610341610d60565b6020026020010151905087878381811061035d5761035d610d60565b905060200281019061036f9190610d8f565b6040810135958601959093506103886020850185610ce2565b73ffffffffffffffffffffffffffffffffffffffff16816103ac6060870187610dcd565b6040516103ba929190610e32565b60006040518083038185875af1925050503d80600081146103f7576040519150601f19603f3d011682016040523d82523d6000602084013e6103fc565b606091505b50602080850191909152901515808452908501351761046d577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260846000fd5b5050600101610325565b508234146104e6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f4d756c746963616c6c333a2076616c7565206d69736d6174636800000000000060448201526064015b60405180910390fd5b50505092915050565b436060828067ffffffffffffffff81111561050c5761050c610d31565b60405190808252806020026020018201604052801561053f57816020015b606081526020019060019003908161052a5790505b5091503660005b8281101561068657600087878381811061056257610562610d60565b90506020028101906105749190610e42565b92506105836020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166105a66020850185610dcd565b6040516105b4929190610e32565b6000604051808303816000865af19150503d80600081146105f1576040519150601f19603f3d011682016040523d82523d6000602084013e6105f6565b606091505b5086848151811061060957610609610d60565b602090810291909101015290508061067d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b50600101610546565b5050509250929050565b43804060606106a086868661085a565b905093509350939050565b6060818067ffffffffffffffff8111156106c7576106c7610d31565b60405190808252806020026020018201604052801561070d57816020015b6040805180820190915260008152606060208201528152602001906001900390816106e55790505b5091503660005b828110156104e657600084828151811061073057610730610d60565b6020026020010151905086868381811061074c5761074c610d60565b905060200281019061075e9190610e76565b925061076d6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166107906040850185610dcd565b60405161079e929190610e32565b6000604051808303816000865af19150503d80600081146107db576040519150601f19603f3d011682016040523d82523d6000602084013e6107e0565b606091505b506020808401919091529015158083529084013517610851577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260646000fd5b50600101610714565b6060818067ffffffffffffffff81111561087657610876610d31565b6040519080825280602002602001820160405280156108bc57816020015b6040805180820190915260008152606060208201528152602001906001900390816108945790505b5091503660005b82811015610a105760008482815181106108df576108df610d60565b602002602001015190508686838181106108fb576108fb610d60565b905060200281019061090d9190610e42565b925061091c6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff1661093f6020850185610dcd565b60405161094d929190610e32565b6000604051808303816000865af19150503d806000811461098a576040519150601f19603f3d011682016040523d82523d6000602084013e61098f565b606091505b506020830152151581528715610a07578051610a07576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b506001016108c3565b5050509392505050565b6000806060610a2b60018686610690565b919790965090945092505050565b60008083601f840112610a4b57600080fd5b50813567ffffffffffffffff811115610a6357600080fd5b6020830191508360208260051b8501011115610a7e57600080fd5b9250929050565b60008060208385031215610a9857600080fd5b823567ffffffffffffffff811115610aaf57600080fd5b610abb85828601610a39565b90969095509350505050565b6000815180845260005b81811015610aed57602081850181015186830182015201610ad1565b81811115610aff576000602083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b600082825180855260208086019550808260051b84010181860160005b84811015610bb1578583037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe001895281518051151584528401516040858501819052610b9d81860183610ac7565b9a86019a9450505090830190600101610b4f565b5090979650505050505050565b602081526000610bd16020830184610b32565b9392505050565b600060408201848352602060408185015281855180845260608601915060608160051b870101935082870160005b82811015610c52577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa0888703018452610c40868351610ac7565b95509284019290840190600101610c06565b509398975050505050505050565b600080600060408486031215610c7557600080fd5b83358015158114610c8557600080fd5b9250602084013567ffffffffffffffff811115610ca157600080fd5b610cad86828701610a39565b9497909650939450505050565b838152826020820152606060408201526000610cd96060830184610b32565b95945050505050565b600060208284031215610cf457600080fd5b813573ffffffffffffffffffffffffffffffffffffffff81168114610bd157600080fd5b600060208284031215610d2a57600080fd5b5035919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81833603018112610dc357600080fd5b9190910192915050565b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112610e0257600080fd5b83018035915067ffffffffffffffff821115610e1d57600080fd5b602001915036819003821315610a7e57600080fd5b8183823760009101908152919050565b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc1833603018112610dc357600080fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa1833603018112610dc357600080fdfea2646970667358221220bb2b5c71a328032f97c676ae39a1ec2148d3e5d6f73d95e9b17910152d61f16264736f6c634300080c00331ca0edce47092c0f398cebf3ffc267f05c8e7076e3b89445e0fe50f6332273d4569ba01b0b9d000e19b24c5869b0fc3b22b0d6fa47cd63316875cbbd577d76e6fde086
    cast publish --rpc-url $RPC_URL $tx

    cd $ROOT

    echo "Deploying permit2"
    cd lib/liquidity-launcher/lib/permit2/
    forge script script/DeployPermit2.s.sol:DeployPermit2 \
        --rpc-url $RPC_URL \
        --private-key $DEPLOYER_PRIVATE_KEY \
        $BROADCAST_ARGS -vv

    cd $ROOT

    source $ROOT/shell-scripts/deploy-auction.sh
    deploy_liquidity_launcher
    deploy_auction
    deploy_virtual_lbp

    fund_local_account

    export DEPLOY_ZK_PASSPORT_VERIFIER="true"

    deployment "dev"

    if [ "$MINT_SOULBOUND_NFTS" = 1 -o "$MINT_SOULBOUND_NFTS" = true ]; then
        echo "Minting soulbound NFTs"
        mint_soulbound_nfts
    fi

    echo "Generating test auction data"
    generate_test_auction_data

    echo "Anvil node is running on port 8545. Press Ctrl+C to stop all processes."
    wait $ANVIL_PID
}

function get_deployment_auction_deployment_block() {
    get_block_from_matcher '.contractName=="FoundationPayload" and .transactionType=="CALL" and .function=="run()"'
}

function get_deployment_atp_factory_deployment_block() {
    get_block_from_matcher '.contractName=="ATPFactory" and .transactionType=="CREATE"'
}

function get_deployment_ignition_participant_soulbound_deployment_block() {
    get_block_from_matcher '.contractName=="IgnitionParticipantSoulbound" and .transactionType=="CREATE"'
}

function get_block_from_matcher() {
    local matcher="$1"
    local collective_deployment_file="$ROOT/broadcast/CollectiveDeploy.s.sol/$CHAIN_ID/run-latest.json"

    local query=".transactions[] | select($matcher) | .hash"
    local hash=$(cat "$collective_deployment_file" | jq -r "$query")
    local block_number=$(cast tx "$hash" --rpc-url "$RPC_URL" --json | jq -r '.blockNumber')
    cast 2d "$block_number"
}

function send_as_foundation_account() {
    local account=0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9

    local target=$1
    local data=$2
    curl -s -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"anvil_impersonateAccount","params":["'"$account"'"],"id":1}' \
      $RPC_URL

    cast send $target $data --from $account --unlocked --rpc-url $RPC_URL
}

function tenderly_send_transaction() {
    local from=$1
    local target=$2
    local data=$3

    curl -s -X POST -H "Content-Type: application/json" \
      --data '{
        "id": 0,
        "jsonrpc": "2.0",
        "method": "tenderly_sendTransaction",
        "params": [{
          "from": "'"$from"'",
          "to": "'"$target"'",
          "gas": "0x0",
          "gasPrice": "0x0",
          "maxFeePerGas": null,
          "maxPriorityFeePerGas": null,
          "value": "0x0",
          "data": "'"$data"'"
        }]
      }' \
      $MAINNET_URL
}

function tenderly_foundation_payload() {
    local fdn=0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9
    local foundation_payload_contract_address=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationPayloadAddress')

    local foundation_actions_target0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget0')
    local foundation_actions_data0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData0')
    echo "Sending foundation action 0"
    echo "Target: $foundation_actions_target0"
    echo "Data: $foundation_actions_data0"
    echo "TENDERLY"
    echo "--------------------------------"
    tenderly_send_transaction $fdn $foundation_actions_target0 $foundation_actions_data0
    local foundation_actions_target1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget1')
    local foundation_actions_data1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData1')
    echo "Sending foundation action 1"
    echo "Target: $foundation_actions_target1"
    echo "Data: $foundation_actions_data1"
    echo "TENDERLY"
    echo "--------------------------------"
    tenderly_send_transaction $fdn $foundation_actions_target1 $foundation_actions_data1

    echo "Sending foundation payload"
    echo "Target: $foundation_payload_contract_address"
    echo "Data: run()"
    echo "TENDERLY"
    echo "--------------------------------"
    tenderly_send_transaction $deployer_address $foundation_payload_contract_address $(cast sig "run()")
    block_number=$(cast bn --rpc-url $RPC_URL)
    AUCTION_CONTRACT_DEPLOY_BLOCK=$block_number
}

function impersonate_foundation_payload() {
    local run_foundation_payload=${1:-"true"}

    local foundation_payload_contract_address=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationPayloadAddress')

    # Impersonate an account against a local Anvil instance, then send a transaction as that account

    # send payload 1
    local foundation_actions_target0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget0')
    local foundation_actions_data0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData0')
    echo "Sending foundation action 0"
    echo "Target: $foundation_actions_target0"
    echo "Data: $foundation_actions_data0"
    echo "--------------------------------"
    send_as_foundation_account $foundation_actions_target0 $foundation_actions_data0

    # send payload 2
    local foundation_actions_target1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget1')
    local foundation_actions_data1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData1')
    echo "Sending foundation action 0"
    echo "Target: $foundation_actions_target0"
    echo "Data: $foundation_actions_data0"
    echo "--------------------------------"
    send_as_foundation_account $foundation_actions_target1 $foundation_actions_data1

    if [ "$run_foundation_payload" = "false" ]; then
        return 0
    fi

    # Send foundation payload from the deployer account
    echo "Sending foundation payload"
    echo "Target: $foundation_payload_contract_address"
    echo "Data: run()"
    echo "--------------------------------"
    txhash=$(cast send $foundation_payload_contract_address "run()" --unlocked --from $deployer_address  --rpc-url $RPC_URL --json | jq -r '.transactionHash')
}

function deployment() {
    # 1. Processes the merkle tree
    # 2. Optionally deploys the aztec contracts
    # 3. Deploys the genesis sale contracts
    # 4. Deploys the twap auction
    local chain_environment=${1:-"sepolia"}

    # Only set CHAIN_ENVIRONMENT_VARIANT if not already defined
    if [ -z "$CHAIN_ENVIRONMENT_VARIANT" ]; then
        if [ "$chain_environment" = "staging" ]; then
            export CHAIN_ENVIRONMENT_VARIANT="FORKED_MAINNET"
        elif [ "$chain_environment" = "prod" ]; then
            export CHAIN_ENVIRONMENT_VARIANT="REAL_MAINNET"
        else
            # We see sepolia as a fresh network as we don't already have a token there
            export CHAIN_ENVIRONMENT_VARIANT="FRESH_NETWORK"
        fi
    fi

    export DEPLOY_ZK_PASSPORT_VERIFIER=${DEPLOY_ZK_PASSPORT_VERIFIER:-"false"}

    if [ "$DEPLOY_ZK_PASSPORT_VERIFIER" = "true" ]; then
        echo "Sourcing deploy-zkpassport-verifiers.sh"
        source $ROOT/shell-scripts/deploy-zkpassport-verifiers.sh
        echo "Deploying zkPassport verifier"
        deploy_zkpassport_verifier
    fi

    # S-1
    echo "Processing merkle tree"
    process_merkle_tree

    if [ -z "$CURRENT_TIMESTAMP" ]; then
        # Not set, calculate current time + 18 minutes
        CURRENT_TIMESTAMP=$(($(date +%s) + 1080))
    fi
    export CURRENT_TIMESTAMP

    echo "Collective Deployment of Contracts"
    cd $ROOT

    # Build the private keys arguments
    local private_key_args=""
    for key in $RAW_PRIVATE_KEYS; do
        private_key_args="$private_key_args --private-keys $key"
    done

    # We set up impersonating the deployer accounts if we are on staging
    if [ "$chain_environment" = "staging" ]; then
        export PRIVATE_KEY_ARGS="--unlocked"
    else
        export PRIVATE_KEY_ARGS="$private_key_args"
    fi

    echo "Deploying collective contracts"
    echo "---------------------------------"
    # Build the rollup with production profile to get proper blob-lib
    FOUNDRY_PROFILE="production" forge build "lib/l1-contracts/src/core/Rollup.sol" --force
    FOUNDRY_PROFILE="production" forge script script/deploy/CollectiveDeploy.s.sol:CollectiveDeploy \
        --rpc-url $RPC_URL \
        $PRIVATE_KEY_ARGS \
        $BROADCAST_ARGS -vvv

    echo "Deployment complete - boyaa"

    # The script outputs to deployments/deployment-{chainId}.json
    # Copy it to the expected location for backwards compatibility
    local AZTEC_DEPLOYMENT_FILE="$DEPLOYMENTS_DIR/collective-l1-deployment-$CHAIN_ID.json"

    # if env=staging; i.e. on a mainnet fork
    if [ "$chain_environment" = "staging" ]; then
        # Note: This sets the AUCTION_CONTRACT_DEPLOY_BLOCK variable
        # impersonate_foundation_payload
        tenderly_foundation_payload
    else
        # NOTE: Will fail to find a block for the auction if mainnet because it haven't happened yet
        AUCTION_CONTRACT_DEPLOY_BLOCK=$(get_deployment_auction_deployment_block)
    fi

    # Write the deployment blocks into the contract addresses files
    IGNITION_PARTICIPANT_SOULBOUND_CONTRACT_DEPLOY_BLOCK=$(get_deployment_ignition_participant_soulbound_deployment_block)
    ATP_FACTORY_DEPLOYMENT_BLOCK=$(get_deployment_atp_factory_deployment_block)

    # write deploy blocks into the aztec deployment file
    jq ". + { \"auctionDeploymentBlock\": \"$AUCTION_CONTRACT_DEPLOY_BLOCK\", \"soulboundTokenDeploymentBlock\": \"$IGNITION_PARTICIPANT_SOULBOUND_CONTRACT_DEPLOY_BLOCK\", \"atpFactoryDeploymentBlock\": \"$ATP_FACTORY_DEPLOYMENT_BLOCK\" }" $AZTEC_DEPLOYMENT_FILE > $AZTEC_DEPLOYMENT_FILE.tmp && mv $AZTEC_DEPLOYMENT_FILE.tmp $AZTEC_DEPLOYMENT_FILE

    if [ -f "$AZTEC_DEPLOYMENT_FILE" ]; then
        cp "$AZTEC_DEPLOYMENT_FILE" "$CONTRACTS_OUTPUT_FILE"
        echo "Saved L1 contract addresses to $CONTRACTS_OUTPUT_FILE"
    else
        echo "Error: Deployment file $AZTEC_DEPLOYMENT_FILE not found"
        exit 1
    fi
}

function mainnet_fork_preamble() {
    # export MAINNET_URL="https://d2jgtsact4tcno.cloudfront.net/$MAINNET_FORK_API_KEY"
    export MAINNET_URL="http://localhost:8545"

    export deployer_address=0x85e51a78FE8FE21d881894206A9adbf54e3Df8c3
    local fdn=0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9
    local predicate_deployer=0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49
    # Fund the accounts
    echo "Funding accounts"
    for key in $deployer_address $fdn $predicate_deployer; do
        cast rpc anvil_setBalance "$key" "0x100000000000000000000067" --rpc-url $MAINNET_URL
    done

    # Impersonate the deployer keys
    for key in $deployer_address $fdn $predicate_deployer; do
        cast rpc anvil_impersonateAccount "$key" --rpc-url $MAINNET_URL
    done
}

function tenderly_fork_preamble() {
    export MAINNET_URL=$RPC_URL

    export deployer_address=0x85e51a78FE8FE21d881894206A9adbf54e3Df8c3
    local fdn=0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9
    local predicate_deployer=0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49
    # Fund the accounts
    set -x
    echo "Funding accounts"
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"tenderly_setBalance","params":[["'$deployer_address'","'$fdn'","'$predicate_deployer'"],"0x100000000000000000000067"],"id":1}' \
        $MAINNET_URL
    set +x
}

function get_zkpassport_domain() {
    local chain_environment=${1:-"sepolia"}
    if [ "$chain_environment" = "sepolia" ]; then
        # CAN GET THIS FROM ENVIRONMENTS and fallback to this
        echo ${SALE_WEBSITE_DOMAIN:-"d1wqou93lfp06y.cloudfront.net"}
    elif [ "$chain_environment" = "staging" ]; then
        echo ${STAGING_SALE_WEBSITE_DOMAIN:-"d3lan9dq8zrpds.cloudfront.net"}
    elif [ "$chain_environment" = "prod" ]; then
        echo "sale.aztec.network"
    else
        echo "Unknown chain environment: $chain_environment"
        exit 1
    fi
}

function deploy_to_chain() {
    local chain_environment=${1:-"sepolia"}

    if [ "$chain_environment" = "sepolia" ]; then
        if [ -n "$SEPOLIA_URL" ]; then
            export RPC_URL=$SEPOLIA_URL
            export CHAIN_ID=11155111
        else
            echo "SEPOLIA_URL not set, skipping deployment, please set SEPOLIA_URL in the environment"
            exit 1
        fi
    elif [ "$chain_environment" = "staging" ]; then
        # Staging takes place on a mainnet fork
        # mainnet_fork_preamble
        tenderly_fork_preamble
        export RPC_URL=$MAINNET_URL
        export CHAIN_ID=1

    elif [ "$chain_environment" = "prod" ]; then
        if [ -n "$MAINNET_URL" ]; then
            echo "Deploying to mainnet!"
            export RPC_URL=$MAINNET_URL
            export CHAIN_ID=1
        else
            echo "MAINNET_URL not set, skipping deployment, please set MAINNET_URL in the environment"
            exit 1
        fi
    else
        echo "Unknown chain environment: $chain_environment"
        exit 1
    fi

    # NOTE: By default if using `deploy-to-chain` we expect the ignition configuration variant to be desired.
    export CONFIGURATION_VARIANT=${CONFIGURATION_VARIANT:-"IGNITION"}

    cd $ROOT
    mkdir -p .contracts/$chain_environment
    export CONTRACTS_OUTPUT_FILE="$ROOT/.contracts/$chain_environment/contract_addresses.json"

    export DEPLOYMENTS_DIR="$ROOT/deployments"

    export ZKPASSPORT_DOMAIN=$(get_zkpassport_domain $chain_environment)

    deployment "$chain_environment"

    echo "Reading data from $CONTRACTS_OUTPUT_FILE"

    export STAKING_ASSET_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.stakingAssetAddress')
    export ROLLUP_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.rollupAddress')
    export ROLLUP_REGISTRY_ADDRESS=$(cat $CONTRACTS_OUTPUT_FILE | jq -r '.registryAddress')

    cat $CONTRACTS_OUTPUT_FILE
}

function run_foundation_payload() {
    local impersonate_foundation_approvals=${1:-"false"}

    export CHAIN_ENVIRONMENT_VARIANT="REAL_MAINNET"
    export CONFIGURATION_VARIANT="IGNITION"
    export DEPLOYMENTS_DIR="$ROOT/deployments"
    export RPC_URL=$MAINNET_URL
    local AZTEC_DEPLOYMENT_FILE="$DEPLOYMENTS_DIR/collective-l1-deployment-1.json"

    if [ "$impersonate_foundation_approvals" = "true" ]; then
        impersonate_foundation_payload false
    else
        local foundation_actions_target0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget0')
        local foundation_actions_data0=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData0')
        local foundation_actions_target1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsTarget1')
        local foundation_actions_data1=$(cat $AZTEC_DEPLOYMENT_FILE | jq -r '.foundationActionsData1')
        echo "===     Foundation actions    ==="
        echo "Foundation action 0:"
        echo "Target: $foundation_actions_target0"
        echo "Data: $foundation_actions_data0"
        echo "Foundation action 1:"
        echo "Target: $foundation_actions_target1"
        echo "Data: $foundation_actions_data1"
        echo "=== End of foundation actions ==="
    fi

    cd $ROOT/script/

    if [ "$DRY_RUN" != "true" ]; then
        FOUNDRY_PROFILE="production" forge script CollectiveDeploy \
            --sig "foundationPayloadRun(bool)" true \
            --rpc-url $RPC_URL \
            $PRIVATE_KEY_ARGS \
            $BROADCAST_ARGS -vvv
    fi

    cd $ROOT
}

function simulate_foundation_step_2_and_3() {
    DEPLOYMENTS_DIR="../deployments" forge script CollectiveDeploy \
        --sig "simulateStep2And3()" \
        --rpc-url $RPC_URL \
        -vv
}

function log_configuration() {
    DEPLOYMENTS_DIR="../deployments" forge script ConfigurationLogging --sig "log_configuration()" -vv --rpc-url $RPC_URL
}

function help() {
    echo "Usage: $0 [ACTION]"
    echo "Available actions:"
    echo "  dev      Deploy all contracts to the local anvil node"
    echo "  deploy-sepolia    Deploy the contracts to sepolia"
    echo "  build    Build the contracts"
    echo "  test     Test the contracts"
    echo "  coverage     Run coverage"
    echo "  admin-mint-tiles <gridId> <count>    Mint random tiles using adminMint"
    echo "  help     Show this help message"
}

ACTION=${1:-"help"}

case $ACTION in
    build)
        build
        ;;
    test)
        test
        ;;
    dev)
        export DEPLOYER_ADDRESS=${DEPLOYER_ADDRESS:-"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
        export DEPLOYER_PRIVATE_KEY=${DEPLOYER_PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
        export RAW_PRIVATE_KEYS="$DEPLOYER_PRIVATE_KEY $TESTING_FOUNDATION_PRIVATE_KEY"
        dev
        ;;
    deploy-sepolia)
        deploy_to_chain "sepolia"
        ;;
    deploy-mainnet)
        deploy_to_chain "prod"
        ;;
    run-foundation-payload)
        run_foundation_payload $2
        ;;
    deploy-staging)
        deploy_to_chain "staging"
        ;;
    coverage)
        coverage
        ;;
    admin-mint-tiles)
        admin_mint_tiles $2 $3
        ;;
    mint-eth-for-account)
        mint_eth_for_account $2
        ;;
    log-configuration)
        log_configuration
        ;;
    simulate-foundation-step-2-and-3)
        simulate_foundation_step_2_and_3
        ;;
    help|*)
        help
        ;;
esac

exit 0
