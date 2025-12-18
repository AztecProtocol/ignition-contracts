// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {StdInvariant} from "forge-std/Test.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {ILATP} from "test/token-vaults/Importer.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";
import {Handler} from "test/token-vaults/foundry_invariant/atps/linear/LATPHandler.sol";

abstract contract LATPInvariantTest is LATPTestBase {
    Handler internal handler;
    ILATP internal atp;
    uint256 internal allocation = 1001e18 + 1; // +1 to make rounding errors more likely

    function deploy() internal virtual;

    function extraChecks() internal view virtual {}

    function setUp() public virtual override {
        super.setUp();

        registry.setExecuteAllowedAt(0);

        handler = new Handler();
        deploy();

        help_upgrade(atp, address(handler));

        uint256 upperTime = atp.getGlobalLock().endTime;
        if (atp.getIsRevokable()) {
            upperTime = Math.max(upperTime, atp.getAccumulationLock().endTime);
        }

        handler.prepare(atp, upperTime);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.prepare.selector;
        selectors[1] = Handler.test.selector;
        excludeSelector(StdInvariant.FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_BalanceGeClaimableAndRevokable() public {
        // Ensure that the balance of the contract is always greater than or equal to the claimable amount
        // plust the revokable amount, ensuring that it is possible for the beneficiary to claim and still
        // have enough funds to cover the revokable amount.

        uint256 claimable = atp.getClaimable();
        uint256 balance = token.balanceOf(address(atp));

        uint256 accumulated = !atp.getIsRevokable() ? allocation : help_computeAccumulated(atp, block.timestamp);
        assertLe(accumulated, allocation, "accumulated <= allocation");

        uint256 revokable = !atp.getIsRevokable() ? 0 : allocation - accumulated;

        uint256 claimed = atp.getClaimed();

        // @note if the global lock has ended, the unlock must not be the minimum, so we use the max value.
        uint256 unlocked = atp.getGlobalLock().endTime <= block.timestamp
            ? type(uint256).max
            : help_computeUnlocked(atp, block.timestamp) - claimed;

        uint256 reward = handler.reward();

        FakeStaker fakeStaker = FakeStaker(address(atp.getStaker()));

        uint256 revoked = handler.isRevoked() ? token.balanceOf(revokeBeneficiary) : 0;

        uint256 allowance = token.allowance(address(atp), address(fakeStaker));
        uint256 staked = fakeStaker.STAKING().staked(address(fakeStaker));

        emit log_named_decimal_uint("block.timestamp", block.timestamp, 0);
        emit log_named_decimal_uint("claimable      ", claimable, 18);
        emit log_named_decimal_uint("balance        ", balance, 18);
        emit log_named_decimal_uint("revokable      ", revokable, 18);
        emit log_named_decimal_uint("unlocked       ", unlocked, 18);
        emit log_named_decimal_uint("claimed        ", claimed, 18);
        emit log_named_decimal_uint("reward         ", reward, 18);
        emit log_named_decimal_uint("allowance      ", allowance, 18);
        emit log_named_decimal_uint("staked         ", staked, 18);
        emit log_named_decimal_uint("revoked        ", revoked, 18);

        assertLe(allowance, atp.getStakeableAmount(), "allowance <= stakeable");

        // If the LATP is revokable, we need to ensure that the revokable amount plus the allowance
        // cannot exceed the balance.
        if (atp.getIsRevokable()) {
            assertLe(revokable + allowance, balance, "revokable + allowance <= balance");
        }

        assertLe(claimable + revokable, balance, "claimable + revokable <= balance");

        emit log_named_decimal_uint("balance - revokable", balance - revokable, 18);
        assertEq(claimable, Math.min(balance - revokable, unlocked), "exitable");

        assertEq(token.balanceOf(address(handler)), claimed, "handler balance != claimed");

        assertEq(
            allocation + handler.reward(),
            balance + staked + revoked + token.balanceOf(address(handler)),
            "allocation == atp + staked + atp + revoker + handler"
        );

        extraChecks();

        // Ensure that everything claimable can indeed be claimed
        if (claimable > 0) {
            // Claim and check that the value would be zero?
            handler.claim();
            assertEq(token.balanceOf(address(atp)), balance - claimable, "atp balance = old balance - claimable");
            assertEq(atp.getClaimable(), 0, "claimable == 0");
        }
    }
}
