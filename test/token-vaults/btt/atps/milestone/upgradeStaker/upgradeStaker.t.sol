// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";

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
    RevokableParams,
    StakerVersion,
    MilestoneId,
    IMATP
} from "test/token-vaults/Importer.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

contract BadStaker is UUPSUpgradeable {
    function getATP() external view returns (address) {
        return address(0xdead);
    }

    function _authorizeUpgrade(address _newImplementation) internal virtual override(UUPSUpgradeable) {}

    function test() external {}
}

contract UpgradeStakerTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal operator = address(bytes20("operator"));

    function setUp() public override(MATPTestBase) {
        super.setUp();

        MilestoneId milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);
        atp.updateStakerOperator(operator);
    }

    function test_WhenCallerIsNotBeneficiary(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        vm.prank(_caller);
        atp.upgradeStaker(fakeStakerVersion);
    }

    modifier whenCallerIsBeneficiary() {
        _;
    }

    function test_whenBadStaker() external whenCallerIsBeneficiary {
        StakerVersion version = registry.getNextStakerVersion();
        registry.registerStakerImplementation(address(new BadStaker()));

        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidUpgrade.selector));
        atp.upgradeStaker(version);
    }

    function test_whenGoodStaker() external whenCallerIsBeneficiary {
        address expectedStakerBefore = registry.getStakerImplementation(StakerVersion.wrap(0));
        address expectedStakerAfter = registry.getStakerImplementation(fakeStakerVersion);

        assertEq(atp.getStaker().getImplementation(), expectedStakerBefore);

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.StakerUpgraded(fakeStakerVersion);
        atp.upgradeStaker(fakeStakerVersion);

        assertEq(atp.getStaker().getImplementation(), expectedStakerAfter);
        assertEq(atp.getStaker().getOperator(), operator);
    }

    function test_whenUpgradingThenDowngrading() external whenCallerIsBeneficiary {
        address expectedStakerBefore = registry.getStakerImplementation(StakerVersion.wrap(0));
        address expectedStakerAfter = registry.getStakerImplementation(fakeStakerVersion);
        address expectedStakerAfterDowngrade = expectedStakerBefore;

        atp.upgradeStaker(fakeStakerVersion);

        assertEq(atp.getStaker().getImplementation(), expectedStakerAfter);
        assertEq(atp.getStaker().getOperator(), operator);

        atp.upgradeStaker(StakerVersion.wrap(0));

        assertEq(atp.getStaker().getImplementation(), expectedStakerAfterDowngrade);
        assertEq(atp.getStaker().getOperator(), operator);
    }
}
