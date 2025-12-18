// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {
    LATP,
    ILATP,
    ILATPCore,
    IATPCore,
    IRegistry,
    LockParams,
    Lock,
    LockLib,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract SetExecuteAllowedAtTest is LATPTestBase {
    ILATP internal atp;

    function setUp() public override(LATPTestBase) {
        super.setUp();

        uint256 allocation = 100e18;

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 250, lockDuration: 1000})
            })
        );
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts

        vm.assume(_caller != address(this));
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        registry.setExecuteAllowedAt(0);
    }

    modifier whenCallerEQOwner() {
        _;
    }

    function test_WhenNewExecuteAllowedAtGECurrentExecuteAllowedAt(uint256 _newExecuteAllowedAt)
        external
        whenCallerEQOwner
    {
        // it reverts
        uint256 currentExecuteAllowedAt = registry.getExecuteAllowedAt();
        uint256 newExecuteAllowedAt = bound(_newExecuteAllowedAt, currentExecuteAllowedAt + 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.InvalidExecuteAllowedAt.selector, newExecuteAllowedAt, currentExecuteAllowedAt
            )
        );
        registry.setExecuteAllowedAt(newExecuteAllowedAt);
    }

    function test_WhenNewExecuteAllowedAtLTCurrentExecuteAllowedAt(uint256 _newExecuteAllowedAt)
        external
        whenCallerEQOwner
    {
        // it updates the executeAllowedAt
        uint256 currentExecuteAllowedAt = registry.getExecuteAllowedAt();
        uint256 cliff = atp.getAccumulationLock().cliff;
        uint256 newExecuteAllowedAt = bound(_newExecuteAllowedAt, cliff, currentExecuteAllowedAt - 1);

        vm.warp(newExecuteAllowedAt);

        // try executing something on the LATP
        vm.expectRevert(
            abi.encodeWithSelector(IATPCore.ExecutionNotAllowedYet.selector, block.timestamp, currentExecuteAllowedAt)
        );
        atp.approveStaker(100);

        vm.expectEmit(true, true, true, true);
        emit IRegistry.UpdatedExecuteAllowedAt(newExecuteAllowedAt);

        registry.setExecuteAllowedAt(newExecuteAllowedAt);
        assertEq(registry.getExecuteAllowedAt(), newExecuteAllowedAt, "executeAllowedAt mismatch");

        // Now we can approve the staker

        address staker = address(atp.getStaker());

        emit log_named_uint("balance", token.balanceOf(address(atp)));

        assertEq(token.allowance(address(atp), staker), 0, "allowance mismatch 0");
        atp.approveStaker(100);
        assertEq(token.allowance(address(atp), staker), 100, "allowance mismatch 1");
    }
}
