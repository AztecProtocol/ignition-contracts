// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {
    IATPFactory,
    ILATPCore,
    ATPFactoryNonces,
    Aztec,
    IMATP,
    LockParams,
    Lock,
    LATPStorage,
    RevokableParams,
    IATPCore,
    IRegistry,
    MilestoneId
} from "test/token-vaults/Importer.sol";

import {ATPFactoryNoncesBase} from "../AtpFactoryNoncesBase.sol";

contract CreateMATPsNoncesTest is ATPFactoryNoncesBase {
    IRegistry internal registry;

    function setUp() public override {
        super.setUp();
        registry = atpFactory.getRegistry();
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        address[] memory beneficiaries = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        MilestoneId[] memory milestoneIds = new MilestoneId[](1);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPFactory.NotMinter.selector, _caller));
        atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);
    }

    modifier whenCallerEQMinter() {
        _;
    }

    function test_WhenLengthsDoesNotMatch() external whenCallerEQMinter {
        // it reverts

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](1);
        MilestoneId[] memory milestoneIds = new MilestoneId[](1);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);

        beneficiaries = new address[](1);
        allocations = new uint256[](2);
        milestoneIds = new MilestoneId[](1);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);

        beneficiaries = new address[](1);
        allocations = new uint256[](1);
        milestoneIds = new MilestoneId[](2);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);
    }

    function test_WhenLengthsMatch() external whenCallerEQMinter {
        // it reverts
        registry.addMilestone();
        registry.addMilestone();

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        MilestoneId[] memory milestoneIds = new MilestoneId[](2);

        beneficiaries[0] = address(1);
        allocations[0] = 100;
        milestoneIds[0] = MilestoneId.wrap(0);

        beneficiaries[1] = address(2);
        allocations[1] = 200;
        milestoneIds[1] = MilestoneId.wrap(1);

        IMATP[] memory atps = atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);

        assertEq(atps.length, 2);

        for (uint256 i = 0; i < atps.length; i++) {
            assertEq(atps[i].getBeneficiary(), beneficiaries[i]);
            assertEq(atps[i].getAllocation(), allocations[i]);
            assertEq(MilestoneId.unwrap(atps[i].getMilestoneId()), MilestoneId.unwrap(milestoneIds[i]));
            assertEq(atps[i].getIsRevoked(), false);
            assertEq(atps[i].getIsRevokable(), true);
        }
    }

    function test_WhenAmountsAndParametersAreTheSame() external whenCallerEQMinter {
        // it uses nonces from the nonce lib
        // it creates and initializes multiple ATPs
        // it transfers _allocation of tokens to the ATPs
        // it returns the ATPs
        registry.addMilestone();

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        MilestoneId[] memory milestoneIds = new MilestoneId[](2);

        address beneficiary = address(1);
        uint256 allocation = 100;
        MilestoneId milestoneId = MilestoneId.wrap(0);

        beneficiaries[0] = beneficiary;
        allocations[0] = allocation;
        milestoneIds[0] = milestoneId;

        beneficiaries[1] = beneficiary;
        allocations[1] = allocation;
        milestoneIds[1] = milestoneId;

        address atpAddress0 = atpFactory.predictMATPAddressWithNonce(beneficiary, allocation, milestoneId, 0);
        address atpAddress1 = atpFactory.predictMATPAddressWithNonce(beneficiary, allocation, milestoneId, 1);

        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiary, atpAddress0, allocation);
        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiary, atpAddress1, allocation);

        IMATP[] memory atps = atpFactory.createMATPs(beneficiaries, allocations, milestoneIds);

        assertEq(atps.length, 2);

        for (uint256 i = 0; i < atps.length; i++) {
            assertEq(atps[i].getBeneficiary(), beneficiaries[i]);
            assertEq(atps[i].getAllocation(), allocations[i]);
            assertEq(MilestoneId.unwrap(atps[i].getMilestoneId()), MilestoneId.unwrap(milestoneIds[i]));
            assertEq(atps[i].getIsRevoked(), false);
            assertEq(atps[i].getIsRevokable(), true);
        }
    }
}
