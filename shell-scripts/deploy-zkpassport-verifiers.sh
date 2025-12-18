#!/bin/bash

export ROOT=$(git rev-parse --show-toplevel)

function deploy_zkpassport_verifier() {
    cd $ROOT

    export PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY
    export DEPLOYER_ADDRESS=$DEPLOYER_ADDRESS
    export DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export ROOT_VERIFIER_ADMIN_ADDRESS=$DEPLOYER_ADDRESS
    export ROOT_VERIFIER_ADMIN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export ROOT_VERIFIER_GUARDIAN_ADDRESS=$DEPLOYER_ADDRESS
    export ROOT_VERIFIER_GUARDIAN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export ROOT_REGISTRY_ADMIN_ADDRESS=$DEPLOYER_ADDRESS
    export ROOT_REGISTRY_ADMIN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export ROOT_REGISTRY_GUARDIAN_ADDRESS=$DEPLOYER_ADDRESS
    export ROOT_REGISTRY_GUARDIAN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export CERTIFICATE_REGISTRY_ADMIN_ADDRESS=$DEPLOYER_ADDRESS
    export CERTIFICATE_REGISTRY_ADMIN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export CERTIFICATE_REGISTRY_ORACLE_ADDRESS=$DEPLOYER_ADDRESS
    export CERTIFICATE_REGISTRY_ORACLE_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export CIRCUIT_REGISTRY_ADMIN_ADDRESS=$DEPLOYER_ADDRESS
    export CIRCUIT_REGISTRY_ADMIN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export CIRCUIT_REGISTRY_ORACLE_ADDRESS=$DEPLOYER_ADDRESS
    export CIRCUIT_REGISTRY_ORACLE_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export SANCTIONS_REGISTRY_ADMIN_ADDRESS=$DEPLOYER_ADDRESS
    export SANCTIONS_REGISTRY_ADMIN_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    export SANCTIONS_REGISTRY_ORACLE_ADDRESS=$DEPLOYER_ADDRESS
    export SANCTIONS_REGISTRY_ORACLE_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    # Deploy the root registry - sourcing this script writes ROOT_REGISTRY_ADDRESS to the environment, which is used by the zkPassport deployment script below
    echo "Deploying zkPassport root registry"
    current_dir=$(pwd)
    cd lib/zkpassport-packages/packages/registry-contracts
    source ./script/test/deploy.sh > /dev/null 2>&1
    export CERTIFICATE_REGISTRY_ROOT=0x2f696abafd61692fe9c82281fd461431f5ff1d3ec31c10b2258b3151d89b9c6d
    export CIRCUIT_REGISTRY_ROOT=0x14012bbfdffc069651619df69390536839878d5f2fb99712fb7da693e9a67c9c
    export SANCTIONS_REGISTRY_ROOT=0x254a1d572d5318fe9e6a7b460b327891d9e3618da071aca12afcf305337bb6de
    # For seed registries
    export ORACLE_ADDRESS=$DEPLOYER_ADDRESS
    export ORACLE_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY

    ./script/test/seed-registries.sh
    cd $current_dir
    echo "Deployed zkPassport root registry"

    # Deploy the zkPassport verifier and extract the address
    export SUB_VERIFIER_VERSION=0x0000000e00010000000000000000000000000000000000000000000000000000
    cd lib/circuits/src/solidity/script
    forge script Deploy.s.sol:Deploy --rpc-url $RPC_URL $BROADCAST_ARGS -vvv
    export ZKPASSPORT_VERIFIER_ADDRESS=$(cat ../deployments/deployment-$CHAIN_ID.json | jq -r '.main.root_verifier')
    echo "Deployed zkPassport verifier"

    cd $current_dir
}

export -f deploy_zkpassport_verifier