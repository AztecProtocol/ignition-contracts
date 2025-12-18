// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Errors} from "@oz/utils/Errors.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {Staking} from "test/token-vaults/mocks/Staking.sol";
import {IERC20Errors} from "@oz/interfaces/draft-IERC6093.sol";

import {
    LATP,
    ILATP,
    IATPCore,
    ATPFactory,
    IRegistry,
    Registry,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract ApproveStakerRevokedTest is LATPTestBase {
    ILATP internal atp;

    address internal staker;

    function setUp() public virtual override(LATPTestBase) {
        super.setUp();

        registry.setExecuteAllowedAt(100);

        atp = atpFactory.createLATP({
            _beneficiary: address(this),
            _revokableParams: RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 250, lockDuration: 1000})
            }),
            _allocation: 1000e18
        });

        staker = address(atp.getStaker());

        vm.label(staker, "Staker");
    }

    function test_WhenCallerNEQBeneficiary(address _caller) external {
        // it reverts

        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        atp.approveStaker(100);
    }

    modifier whenCallerEQBeneficiary() {
        _;
    }

    function test_WhenTimeLTEXECUTE_ALLOWED_AT(uint256 _time) external whenCallerEQBeneficiary {
        // it reverts
        uint256 time = bound(_time, 0, atp.getExecuteAllowedAt() - 1);

        vm.warp(time);
        vm.expectRevert(
            abi.encodeWithSelector(IATPCore.ExecutionNotAllowedYet.selector, time, atp.getExecuteAllowedAt())
        );
        atp.approveStaker(100);
    }

    function test_WhenTimeGEEXECUTE_ALLOWED_AT(uint256 _time, uint256 _amount) external whenCallerEQBeneficiary {
        uint256 executableAt = atp.getExecuteAllowedAt();
        uint256 endTime = atp.getAccumulationLock().endTime;
        uint256 time = bound(_time, executableAt, endTime - 1);

        vm.warp(time);

        // it updates allowance

        // When the LATP is revoked, it will behave similarly to a non-revokable LATP
        // as it cannot be revoked again.
        // For the sake of it, we will be jumping far enough into the future such that there is at least some allocation.
        uint256 cliff = atp.getAccumulationLock().cliff;
        time = bound(_time, Math.max(block.timestamp, cliff), endTime - 1);
        vm.warp(time);

        uint256 allocation = help_computeAccumulated(atp, block.timestamp);
        uint256 amount = bound(_amount, 1, allocation);

        address revoker = atp.getRevoker();
        vm.prank(revoker);
        atp.revoke();

        assertEq(token.balanceOf(revokeBeneficiary), atp.getAllocation() - allocation, "revoke beneficiary");
        assertEq(token.balanceOf(address(atp)), allocation, "balance");

        assertEq(token.allowance(address(atp), staker), 0);

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.ApprovedStaker(amount);
        atp.approveStaker(amount);

        assertEq(token.allowance(address(atp), staker), amount);
    }
}
