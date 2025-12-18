// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {
    IATPFactory,
    ATPFactoryNonces,
    Aztec,
    ILATP,
    LockParams,
    Lock,
    LATPStorage,
    ILATPCore,
    IATPCore,
    RevokableParams
} from "test/token-vaults/Importer.sol";

import {ATPFactoryNoncesBase} from "../AtpFactoryNoncesBase.sol";

contract CreateLATPsNoncesTest is ATPFactoryNoncesBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts

        vm.assume(_caller != address(this));

        address[] memory beneficiaries = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        RevokableParams[] memory revokablParams = new RevokableParams[](1);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPFactory.NotMinter.selector, _caller));
        atpFactory.createLATPs(beneficiaries, allocations, revokablParams);
    }

    modifier whenCallerEQOwner() {
        _;
    }

    function test_WhenLengthsDoesNotMatch() external whenCallerEQOwner {
        // it reverts

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](1);
        RevokableParams[] memory revokableParams = new RevokableParams[](1);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createLATPs(beneficiaries, allocations, revokableParams);

        beneficiaries = new address[](1);
        allocations = new uint256[](2);
        revokableParams = new RevokableParams[](1);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createLATPs(beneficiaries, allocations, revokableParams);

        beneficiaries = new address[](1);
        allocations = new uint256[](1);
        revokableParams = new RevokableParams[](2);

        vm.expectRevert(abi.encodeWithSelector(IATPFactory.InvalidInputLength.selector));
        atpFactory.createLATPs(beneficiaries, allocations, revokableParams);
    }

    function test_WhenLengthsMatch() external whenCallerEQOwner {
        // it creates and initializes multiple LATPs
        // it transfers _allocation of tokens to the LATPs
        // it returns the LATPs

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        RevokableParams[] memory revokableParams = new RevokableParams[](2);

        beneficiaries[0] = address(1);
        allocations[0] = 100;

        beneficiaries[1] = address(2);
        allocations[1] = 200;
        revokableParams[1].revokeBeneficiary = address(3);
        revokableParams[1].lockParams = LockParams(1, 2, 3);

        address atpAddress0 = atpFactory.predictLATPAddress(beneficiaries[0], allocations[0], revokableParams[0]);
        address atpAddress1 = atpFactory.predictLATPAddress(beneficiaries[1], allocations[1], revokableParams[1]);

        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiaries[0], atpAddress0, allocations[0]);
        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiaries[1], atpAddress1, allocations[1]);

        ILATP[] memory atps = atpFactory.createLATPs(beneficiaries, allocations, revokableParams);

        {
            ILATP atp = atps[0];
            assertEq(atp.getBeneficiary(), beneficiaries[0]);
            assertEq(atp.getAllocation(), allocations[0]);

            assertFalse(atp.getIsRevokable());

            vm.expectRevert(IATPCore.NotRevokable.selector);
            atp.getAccumulationLock();

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 0);
            assertEq(store.accumulationCliffDuration, 0);
            assertEq(store.accumulationLockDuration, 0);
            assertEq(store.isRevokable, false);
            assertEq(store.revokeBeneficiary, address(0));
            assertEq(atp.getRevokeBeneficiary(), address(0));

            assertEq(aztec.balanceOf(address(atp)), allocations[0]);
        }

        {
            ILATP atp = atps[1];
            assertEq(atp.getBeneficiary(), beneficiaries[1]);
            assertEq(atp.getAllocation(), allocations[1]);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, allocations[1]);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(3));
            assertEq(atp.getRevokeBeneficiary(), address(3));
            assertEq(aztec.balanceOf(address(atp)), allocations[1]);
        }
    }

    function test_WhenAmountsAndParametersAreTheSame() external {
        // It uses a nonce from the nonce lib
        // it creates and initializes an LATP
        // it transfers _allocation of tokens to the LATP
        // it returns the LATP

        // When checking the events, we don't yet know the address of the LATP.
        // As we don't do deterministic deployments of

        address[] memory beneficiaries = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        RevokableParams[] memory revokableParams = new RevokableParams[](2);

        beneficiaries[0] = address(1);
        allocations[0] = 100;
        revokableParams[0].revokeBeneficiary = address(3);
        revokableParams[0].lockParams = LockParams(1, 2, 3);

        beneficiaries[1] = beneficiaries[0];
        allocations[1] = allocations[0];
        revokableParams[1].revokeBeneficiary = revokableParams[0].revokeBeneficiary;
        revokableParams[1].lockParams = revokableParams[0].lockParams;

        address atpAddress0 =
            atpFactory.predictLATPAddressWithNonce(beneficiaries[0], allocations[0], revokableParams[0], 0);
        address atpAddress1 =
            atpFactory.predictLATPAddressWithNonce(beneficiaries[1], allocations[1], revokableParams[1], 1);

        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiaries[0], atpAddress0, allocations[0]);
        vm.expectEmit(true, true, true, true);
        emit IATPFactory.ATPCreated(beneficiaries[1], atpAddress1, allocations[1]);

        ILATP[] memory atps = atpFactory.createLATPs(beneficiaries, allocations, revokableParams);

        {
            ILATP atp = atps[0];
            assertEq(atp.getBeneficiary(), beneficiaries[0]);
            assertEq(atp.getAllocation(), allocations[0]);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, allocations[1]);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(3));
            assertEq(atp.getRevokeBeneficiary(), address(3));
            assertEq(aztec.balanceOf(address(atp)), allocations[1]);
        }

        {
            ILATP atp = atps[1];
            assertEq(atp.getBeneficiary(), beneficiaries[1]);
            assertEq(atp.getAllocation(), allocations[1]);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, allocations[1]);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(3));
            assertEq(atp.getRevokeBeneficiary(), address(3));
            assertEq(aztec.balanceOf(address(atp)), allocations[1]);
        }
    }
}
