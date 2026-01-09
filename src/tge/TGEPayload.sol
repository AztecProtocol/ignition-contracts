// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {IRegistry as IATPRegistry} from "@atp/Registry.sol";
import {IRollupCore} from "@aztec/core/interfaces/IRollup.sol";
import {IPayload} from "@aztec/governance/interfaces/IPayload.sol";
import {IDateGatedRelayer} from "@aztec/periphery/interfaces/IDateGatedRelayer.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPWithdrawableAndClaimableStakerV2, IRegistry} from "src/tge/ATPWithdrawableAndClaimableStakerV2.sol";
import {GovernanceAcceleratedLock} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

contract TGEPayload is IPayload {
    IATPRegistry public constant ATP_REGISTRY = IATPRegistry(0x63841bAD6B35b6419e15cA9bBBbDf446D4dC3dde);
    IVirtualLBPStrategyBasic public constant VIRTUAL_LBP_STRATEGY =
        IVirtualLBPStrategyBasic(0xd53006d1e3110fD319a79AEEc4c527a0d265E080);
    IRegistry public constant ROLLUP_REGISTRY = IRegistry(0x35b22e09Ee0390539439E24f06Da43D83f90e298);
    IERC20 public constant AZTEC_TOKEN = IERC20(0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2);
    StakingRegistry public constant STAKING_REGISTRY = StakingRegistry(0x042dF8f42790d6943F41C25C2132400fd727f452);
    address public constant DATE_GATED_RELAYER_SHORT = 0x7d6DECF157E1329A20c4596eAf78D387E896aa4e;
    address public constant ROLLUP = 0x603bb2c05D474794ea97805e8De69bCcFb3bCA12;

    // Jan 1, 2026 00:00:00 CET (Dec 31, 2025 23:00:00 UTC) - a Thursday
    uint256 public constant JAN_1_2026_CET = 1767222000;

    // Day of week constants (Monday = 0, Sunday = 6)
    uint256 internal constant MONDAY = 0;
    uint256 internal constant TUESDAY = 1;
    uint256 internal constant WEDNESDAY = 2;
    uint256 internal constant THURSDAY = 3;
    uint256 internal constant FRIDAY = 4;
    uint256 internal constant SATURDAY = 5;
    uint256 internal constant SUNDAY = 6;

    // Configurable business hours (CET)
    uint256 public constant START_OF_WORKDAY = 8 hours;
    uint256 public constant END_OF_WORKDAY = 15 hours;
    uint256 public constant START_DAY = TUESDAY;
    uint256 public constant END_DAY = THURSDAY;

    ATPWithdrawableAndClaimableStakerV2 public immutable STAKER;

    error OutsideBusinessHours(uint256 secondsSinceMidnightCET, uint256 dayOfWeek);

    modifier inBusinessHours() {
        // Constraint: Since it opens up for trading, and will be aligned with centralized exchanges,
        // execution should only happen during configured business hours and days (in CET)

        uint256 timeSinceReference = block.timestamp - JAN_1_2026_CET;
        uint256 secondsSinceMidnight = timeSinceReference % 1 days;

        // Calculate day of week with Monday=0, Sunday=6
        // Jan 1, 2026 was a Thursday (day 3 in Monday=0), so we add 3
        uint256 daysSinceReference = timeSinceReference / 1 days;
        uint256 dayOfWeek = (daysSinceReference + 3) % 7;

        require(
            secondsSinceMidnight >= START_OF_WORKDAY && secondsSinceMidnight < END_OF_WORKDAY && dayOfWeek >= START_DAY
                && dayOfWeek <= END_DAY,
            OutsideBusinessHours(secondsSinceMidnight, dayOfWeek)
        );

        _;
    }

    constructor() {
        STAKER =
            new ATPWithdrawableAndClaimableStakerV2(AZTEC_TOKEN, ROLLUP_REGISTRY, STAKING_REGISTRY, block.timestamp);
    }

    function getActions() external view override(IPayload) inBusinessHours returns (IPayload.Action[] memory) {
        // [ ] 0. Accelerate the lock
        // [ ] 1. Accept the ownership
        // [ ] 2. Set the unlock start time
        // [ ] 3. Register the staker
        // [ ] 4. Approve the migration (allow trading)
        // [ ] 5. Make rewards claimable

        IPayload.Action[] memory actions = new IPayload.Action[](6);

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
                abi.encodeWithSelector(IATPRegistry.setUnlockStartTime.selector, block.timestamp - 365 days)
            )
        });

        actions[3] = IPayload.Action({
            target: DATE_GATED_RELAYER_SHORT,
            data: abi.encodeWithSelector(
                IDateGatedRelayer.relay.selector,
                address(ATP_REGISTRY),
                abi.encodeWithSelector(IATPRegistry.registerStakerImplementation.selector, address(STAKER))
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

        actions[5] = IPayload.Action({
            target: ROLLUP, data: abi.encodeWithSelector(IRollupCore.setRewardsClaimable.selector, true)
        });

        return actions;
    }

    function getURI() external pure override(IPayload) returns (string memory) {
        return "https://github.com/AztecProtocol/ignition-contracts/";
    }
}
