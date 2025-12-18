// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {StdInvariant} from "forge-std/Test.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {IMATP, MilestoneId} from "test/token-vaults/Importer.sol";
import {Handler} from "test/token-vaults/foundry_invariant/atps/milestone/MATPHandler.sol";

contract MATPInvariantTest is MATPTestBase {
    Handler internal handler;
    IMATP internal atp;
    uint256 internal allocation = 1001e18 + 1; // +1 to make rounding errors more likely

    function setUp() public virtual override {
        super.setUp();

        registry.setExecuteAllowedAt(0);

        handler = new Handler();

        MilestoneId milestoneId = registry.addMilestone();

        atp = atpFactory.createMATP(address(handler), allocation, milestoneId);

        vm.prank(address(handler));
        atp.updateStakerOperator(address(handler));

        // Upgrades the staker to be the `FakeStaker`
        help_upgrade(atp);

        uint256 upperTime = atp.getGlobalLock().endTime + 60 * 60 * 24 * 365;

        handler.prepare(atp, upperTime);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.prepare.selector;
        selectors[1] = Handler.test.selector;
        excludeSelector(StdInvariant.FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_HandlerCannotExitFunds() public view {
        // The balance of the handler should not increase no matter what the handler does
        // as long as the atp is not revoked and it not the milestone is not succeeded
        // Also the claimable should be 0
        assertEq(atp.getBeneficiary(), address(handler));
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(atp.getClaimable(), 0);
    }

    function invariant_AssetsCannotExit() public view {
        // Beyond the handler not beneficiary not being able to exit funds.
        // We wish to check that the assets don't end up outside the atp or staking
        uint256 rewards = handler.reward();
        uint256 atpBalance = token.balanceOf(address(atp));
        uint256 staked = handler.staking().staked(address(atp.getStaker()));
        uint256 claimableRewards = handler.staking().rewards(address(atp.getStaker()));

        assertEq(atpBalance + staked + claimableRewards, allocation + rewards);
    }
}
