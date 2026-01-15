// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Aztec Labs.
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";
import {TGEPayload} from "src/tge/TGEPayload.sol";

/**
 * @notice Script to deploy the TGE payload
 * If you want to deploy this:
 * forge script TGEDeploy -vvv --sig "deploy()" --rpc-url <RPC_URL> --verifier etherscan --etherscan-api-key <ETHERSCAN_API_KEY> \
 * --broadcast --private-key <ONE_TIME_PRIVATE_KEY>
 */
contract TGEDeploy is Test {
    function deploy() public {
        vm.broadcast();
        TGEPayload tgePayload = new TGEPayload();
        emit log_named_address("TGEPayload", address(tgePayload));
    }
}
