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
    ILATPCore,
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

contract ApproveStakerNonRevokedTest is LATPTestBase {
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

    modifier whenTimeGEEXECUTE_ALLOWED_AT(uint256 _time) {
        uint256 executableAT = atp.getExecuteAllowedAt();
        uint256 endTime = atp.getAccumulationLock().endTime;
        uint256 time = bound(_time, executableAT, endTime - 1);

        vm.warp(time);
        _;
    }

    function test_GivenBalanceLTRequired(uint256 _time, uint256 _amount)
        external
        whenCallerEQBeneficiary
        whenTimeGEEXECUTE_ALLOWED_AT(_time)
    {
        // it reverts

        uint256 accumulated = help_computeAccumulated(atp, block.timestamp);
        uint256 debt = atp.getAllocation() - accumulated;
        uint256 amount = bound(_amount, accumulated + 1, atp.getAllocation());
        uint256 balance = token.balanceOf(address(atp));

        assertEq(token.allowance(address(atp), staker), 0);

        uint256 stakeable = atp.getStakeableAmount();
        assertEq(stakeable, balance - debt);

        vm.expectRevert(abi.encodeWithSelector(ILATPCore.InsufficientStakeable.selector, stakeable, amount));
        atp.approveStaker(amount);

        assertEq(token.allowance(address(atp), staker), 0);
    }

    function test_GivenBalanceGeRequired(uint256 _time, uint256 _amount)
        external
        whenCallerEQBeneficiary
        whenTimeGEEXECUTE_ALLOWED_AT(_time)
    {
        // it updates allowance

        uint256 accumulated = help_computeAccumulated(atp, block.timestamp);

        assertEq(token.allowance(address(atp), staker), 0);

        uint256 amount = bound(_amount, 0, accumulated);

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.ApprovedStaker(amount);
        atp.approveStaker(amount);

        assertEq(token.allowance(address(atp), staker), amount);
    }
}
