// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {IPayload} from "@aztec/governance/interfaces/IPayload.sol";
import {IRegistry as IATPRegistry, StakerVersion} from "@atp/Registry.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IDateGatedRelayer} from "@aztec/periphery/interfaces/IDateGatedRelayer.sol";
import {GovernanceAcceleratedLock} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";

contract Payload90 is IPayload {
    IATPRegistry public immutable ATP_REGISTRY;
    ATPWithdrawableAndClaimableStaker public immutable STAKER;
    IVirtualLBPStrategyBasic public immutable VIRTUAL_LBP_STRATEGY;
    address public immutable DATE_GATED_RELAYER_SHORT;

    constructor(
        IATPRegistry _atpRegistry,
        IRegistry _rollupRegistry,
        IERC20 _stakingAsset,
        StakingRegistry _stakingRegistry,
        IVirtualLBPStrategyBasic _virtualLBPStrategyBasic,
        address _dateGatedRelayerShort
    ) {
        require(address(_atpRegistry) != address(0));
        require(address(_rollupRegistry) != address(0));
        require(address(_stakingAsset) != address(0));
        require(address(_stakingRegistry) != address(0));
        require(address(_virtualLBPStrategyBasic) != address(0));
        require(address(_dateGatedRelayerShort) != address(0));

        ATP_REGISTRY = _atpRegistry;
        STAKER =
            new ATPWithdrawableAndClaimableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry, block.timestamp);
        VIRTUAL_LBP_STRATEGY = _virtualLBPStrategyBasic;
        DATE_GATED_RELAYER_SHORT = _dateGatedRelayerShort;
    }

    function getURI() external pure override(IPayload) returns (string memory) {
        return "Payload90";
    }

    function getActions() external view override(IPayload) returns (IPayload.Action[] memory) {
        IPayload.Action[] memory actions = new IPayload.Action[](5);

        StakerVersion version = ATP_REGISTRY.getNextStakerVersion();

        actions[0] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(GovernanceAcceleratedLock.accelerateLock.selector)
        });

        actions[1] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(
                IDateGatedRelayer.relay.selector,
                address(ATP_REGISTRY),
                abi.encodeWithSelector(Ownable2Step.acceptOwnership.selector)
            )
        });

        actions[2] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(
                IDateGatedRelayer.relay.selector,
                address(ATP_REGISTRY),
                abi.encodeWithSelector(IATPRegistry.registerStakerImplementation.selector, address(STAKER))
            )
        });

        actions[3] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(
                IDateGatedRelayer.relay.selector,
                address(ATP_REGISTRY),
                abi.encodeWithSelector(IATPRegistry.setUnlockStartTime.selector, block.timestamp - 365 days)
            )
        });

        actions[4] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(
                IDateGatedRelayer.relay.selector,
                address(VIRTUAL_LBP_STRATEGY),
                abi.encodeWithSelector(IVirtualLBPStrategyBasic.approveMigration.selector)
            )
        });

        return actions;
    }
}
