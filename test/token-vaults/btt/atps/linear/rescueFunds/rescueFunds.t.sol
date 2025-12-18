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

contract RescueFundsTest is LATPTestBase {
    ILATP public atp;
    IERC20 public tokenInput;

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
        atp.rescueFunds(address(0), _caller);
    }

    modifier whenCallerIsBeneficiary() {
        _;
    }

    function test_WhenAssetIsUnlockingToken() external whenCallerIsBeneficiary {
        // it reverts
        address asset = address(atp.getToken());
        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidAsset.selector, asset));
        atp.rescueFunds(asset, address(this));
    }

    function test_WhenAssetIsNotUnlockingToken(uint256 _balance) external whenCallerIsBeneficiary {
        // it transfers entire balance to recipient

        uint256 balance = bound(_balance, 0, type(uint128).max);

        MockERC20 asset = new MockERC20();
        asset.initialize("Test", "TEST", 18);
        deal(address(asset), address(atp), balance);

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.Rescued(address(asset), address(this), balance);
        atp.rescueFunds(address(asset), address(this));

        assertEq(asset.balanceOf(address(this)), balance);
    }
}
