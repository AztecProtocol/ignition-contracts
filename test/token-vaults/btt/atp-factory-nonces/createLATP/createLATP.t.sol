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
    ILATP,
    LockParams,
    Lock,
    LATPStorage,
    RevokableParams,
    IATPCore
} from "test/token-vaults/Importer.sol";

import {ATPFactoryNoncesBase} from "../AtpFactoryNoncesBase.sol";

contract CreateLATPNoncesTest is ATPFactoryNoncesBase {
    RevokableParams internal revokableParams;

    function setUp() public override {
        super.setUp();

        revokableParams = RevokableParams({
            revokeBeneficiary: address(0), lockParams: LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0})
        });
    }

    function test_WhenCallerNEQMinter(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPFactory.NotMinter.selector, _caller));
        atpFactory.createLATP(address(1), 100, revokableParams);
    }

    function test_WhenCallerEQMinter() external {
        // it creates and initializes an LATP
        // it transfers _allocation of tokens to the LATP
        // it returns the LATP

        // When checking the events, we don't yet know the address of the LATP.
        // As we don't do deterministic deployments of

        {
            address atpAddress = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atpAddress, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertFalse(atp.getIsRevokable());

            vm.expectRevert(IATPCore.NotRevokable.selector);
            atp.getAccumulationLock();

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 0);
            assertEq(store.accumulationCliffDuration, 0);
            assertEq(store.accumulationLockDuration, 0);
            assertEq(store.isRevokable, false);
            assertEq(store.revokeBeneficiary, address(0));
            assertEq(aztec.balanceOf(address(atp)), 100);
        }

        {
            revokableParams.revokeBeneficiary = address(2);
            revokableParams.lockParams = LockParams({startTime: 1, cliffDuration: 2, lockDuration: 3});
            address atpAddress = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atpAddress, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, 100);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(2));

            assertEq(aztec.balanceOf(address(atp)), 100);
        }
    }

    function test_WhenAnATPWithRepeatedOwnerAndAmountIsCreated() external {
        // It uses a nonce from the nonce lib
        // it creates and initializes an LATP
        // it transfers _allocation of tokens to the LATP
        // it returns the LATP

        // When checking the events, we don't yet know the address of the LATP.
        // As we don't do deterministic deployments of

        address atp0Address;
        address atp1Address;
        {
            atp0Address = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atp0Address, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(address(atp), atp0Address);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertFalse(atp.getIsRevokable());

            vm.expectRevert(IATPCore.NotRevokable.selector);
            atp.getAccumulationLock();

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 0);
            assertEq(store.accumulationCliffDuration, 0);
            assertEq(store.accumulationLockDuration, 0);
            assertEq(store.isRevokable, false);
            assertEq(store.revokeBeneficiary, address(0));
            assertEq(aztec.balanceOf(address(atp)), 100);
        }

        // Deploy the same ATP
        {
            atp1Address = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atp1Address, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(address(atp), atp1Address);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertFalse(atp.getIsRevokable());

            vm.expectRevert(IATPCore.NotRevokable.selector);
            atp.getAccumulationLock();

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 0);
            assertEq(store.accumulationCliffDuration, 0);
            assertEq(store.accumulationLockDuration, 0);
            assertEq(store.isRevokable, false);
            assertEq(store.revokeBeneficiary, address(0));
            assertEq(aztec.balanceOf(address(atp)), 100);
        }
        assertNotEq(atp0Address, atp1Address);

        address atp2Address;
        address atp3Address;

        // Update the revokable params
        revokableParams.revokeBeneficiary = address(2);
        revokableParams.lockParams = LockParams({startTime: 1, cliffDuration: 2, lockDuration: 3});
        {
            atp2Address = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atp2Address, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(address(atp), atp2Address);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, 100);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(2));

            assertEq(aztec.balanceOf(address(atp)), 100);
        }

        {
            atp3Address = atpFactory.predictLATPAddress(address(1), 100, revokableParams);

            vm.expectEmit(true, true, true, true);
            emit IATPFactory.ATPCreated(address(1), atp3Address, 100);
            ILATP atp = atpFactory.createLATP(address(1), 100, revokableParams);

            assertEq(address(atp), atp3Address);

            assertEq(atp.getBeneficiary(), address(1));
            assertEq(atp.getAllocation(), 100);

            assertTrue(atp.getIsRevokable());

            Lock memory accumulationLock = atp.getAccumulationLock();

            assertEq(accumulationLock.startTime, 1);
            assertEq(accumulationLock.cliff, 3);
            assertEq(accumulationLock.endTime, 4);
            assertEq(accumulationLock.allocation, 100);

            LATPStorage memory store = atp.getStore();

            assertEq(store.accumulationStartTime, 1);
            assertEq(store.accumulationCliffDuration, 2);
            assertEq(store.accumulationLockDuration, 3);
            assertEq(store.isRevokable, true);
            assertEq(store.revokeBeneficiary, address(2));

            assertEq(aztec.balanceOf(address(atp)), 100);
        }
        assertNotEq(atp2Address, atp3Address);
    }
}
