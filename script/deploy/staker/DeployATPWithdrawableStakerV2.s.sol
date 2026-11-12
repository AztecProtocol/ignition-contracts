// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Aztec Labs.
pragma solidity >=0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IRegistry as IATPRegistry} from "@atp/Registry.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPWithdrawableStakerV2} from "src/staking/ATPWithdrawableStakerV2.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";

/**
 * @notice Deploys `ATPWithdrawableStakerV2`. Any account can deploy it.
 *
 * Usage:
 *   forge script DeployATPWithdrawableStakerV2 --sig "deploy()" --rpc-url $RPC_URL --broadcast --verify
 *
 * The owner of the registries below then calls `registerStakerImplementation(<staker>)` on each of them,
 * e.g. from the registry's "Write Contract" tab on Etherscan.
 */
contract DeployATPWithdrawableStakerV2 is Script {
    IERC20 public constant AZTEC_TOKEN = IERC20(0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2);
    IRegistry public constant ROLLUP_REGISTRY = IRegistry(0x35b22e09Ee0390539439E24f06Da43D83f90e298);
    IStakingRegistry public constant STAKING_REGISTRY = IStakingRegistry(0x042dF8f42790d6943F41C25C2132400fd727f452);

    IATPRegistry public constant ATP_REGISTRY_A = IATPRegistry(0xD938bE4A2cB41105Bc2FbE707dca124A2e5d0c80);
    IATPRegistry public constant ATP_REGISTRY_B = IATPRegistry(0x667d2641cb96734f386adA6A9afCF07B1815fB8b);

    function deploy() public returns (ATPWithdrawableStakerV2 staker) {
        vm.startBroadcast();
        staker = new ATPWithdrawableStakerV2(AZTEC_TOKEN, ROLLUP_REGISTRY, STAKING_REGISTRY);
        vm.stopBroadcast();

        console.log("ATPWithdrawableStakerV2:", address(staker));
    }
}
