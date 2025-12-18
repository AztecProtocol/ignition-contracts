// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {
    LATP,
    ILATP,
    ILATPCore,
    IATPCore,
    ATPFactory,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract UpdateStakerOperatorTest is LATPTestBase {
    ILATP public atp;
    IERC20 public tokenInput;

    address internal operator = address(bytes20("operator"));

    function setUp() public override(LATPTestBase) {
        super.setUp();

        atp = atpFactory.createLATP(
            address(this),
            1000e18,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 0, lockDuration: 1000})
            })
        );
    }

    function test_WhenCallerIsNotBeneficiary(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        vm.prank(_caller);
        atp.updateStakerOperator(address(0xdead));
    }

    function test_whenCallerIsBeneficiary() external {
        // it updates the operator

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.StakerOperatorUpdated(address(0xdead));

        atp.updateStakerOperator(address(0xdead));

        assertEq(atp.getStaker().getOperator(), address(0xdead));
    }
}
