// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {IPayload} from "@aztec/governance/interfaces/IPayload.sol";
import {Prepare90Base} from "./Prepare90Base.sol";
import {Payload90} from "../Payload90.sol";
import {IRegistry as IATPRegistry} from "@atp/Registry.sol";
import {IRegistry as IRollupRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

// Should be ran from a sequencer attester key
contract SignalPropoal is Prepare90Base {
    function deployPayload() public {
        string memory json = _loadJson();

        vm.broadcast();
        Payload90 payload90 = new Payload90(
            IATPRegistry(vm.parseJsonAddress(json, ".atpRegistryAuction")),
            IRollupRegistry(vm.parseJsonAddress(json, ".registryAddress")),
            IERC20(vm.parseJsonAddress(json, ".stakingAssetAddress")),
            StakingRegistry(vm.parseJsonAddress(json, ".stakingRegistry")),
            IVirtualLBPStrategyBasic(payable(vm.parseJsonAddress(json, ".virtualLBP"))),
            vm.parseJsonAddress(json, ".twapDateGatedRelayer")
        );

        emit log_named_address("Payload 90 address", address(payload90));
    }

    function run(address _payloadAddress) public {
        string memory json = _loadJson();

        GovernanceProposer proposer = GovernanceProposer(vm.parseJsonAddress(json, ".governanceProposerAddress"));
        IPayload payload90 = IPayload(_payloadAddress);

        vm.broadcast();
        proposer.signal(payload90);
    }
}
