// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Initializable} from "@oz/proxy/utils/Initializable.sol";
import {Clones} from "@oz/proxy/Clones.sol";

import {
    LATP,
    IRegistry,
    LockParams,
    Lock,
    LockLib,
    LATPStorage,
    ILATPCore,
    IATPCore,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract InitializeTest is LATPTestBase {
    LATP internal implementation;
    LATP internal atp;
    RevokableParams internal revokableParams =
        RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()});

    function setUp() public override {
        super.setUp();

        implementation = new LATP(registry, token);
        atp = LATP(Clones.clone(address(implementation)));
    }

    function test_whenTryingToInitializeImplementation() external {
        vm.expectRevert(abi.encodeWithSelector(IATPCore.AlreadyInitialized.selector));
        implementation.initialize(address(3), 100, revokableParams);
    }

    function test_GivenAlreadyInitialize() external {
        // it reverts

        atp.initialize(address(3), 100, revokableParams);

        vm.expectRevert(abi.encodeWithSelector(IATPCore.AlreadyInitialized.selector));
        atp.initialize(address(3), 100, revokableParams);
    }

    modifier givenStakerEQAddressZero() {
        _;
    }

    function test_GivenBeneficiaryEQAddressZero() external givenStakerEQAddressZero {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidBeneficiary.selector, address(0)));
        atp.initialize(address(0), 100, revokableParams);
    }

    modifier givenBeneficiaryNEQAddressZero() {
        _;
    }

    function test_GivenAllocationEQ0() external givenStakerEQAddressZero givenBeneficiaryNEQAddressZero {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IATPCore.AllocationMustBeGreaterThanZero.selector));
        atp.initialize(address(3), 0, revokableParams);
    }

    modifier givenAllocationGT0() {
        _;
    }

    modifier whenRevokeBeneficiaryEQAddressZero() {
        _;
    }

    function test_WhenRevokableLockParamsNEQEmpty()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenRevokeBeneficiaryEQAddressZero
    {
        // it reverts

        revokableParams.lockParams.startTime = 1;
        vm.expectRevert(ILATPCore.LockParamsMustBeEmpty.selector);
        atp.initialize(address(3), 100, revokableParams);

        revokableParams.lockParams.startTime = 0;
        revokableParams.lockParams.cliffDuration = 1;
        vm.expectRevert(ILATPCore.LockParamsMustBeEmpty.selector);
        atp.initialize(address(3), 100, revokableParams);

        revokableParams.lockParams.cliffDuration = 0;
        revokableParams.lockParams.lockDuration = 1;
        vm.expectRevert(ILATPCore.LockParamsMustBeEmpty.selector);
        atp.initialize(address(3), 100, revokableParams);
    }

    function test_WhenRevokableLockParamsIsEmpty()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenRevokeBeneficiaryEQAddressZero
    {
        // it updates the allocation
        // it updates the beneficiary
        // it updates the staker

        atp.initialize(address(3), 100, revokableParams);

        assertEq(atp.getAllocation(), 100);
        assertEq(atp.getBeneficiary(), address(3));
        assertNotEq(address(atp.getStaker()), address(0));
        assertEq(address(atp.getStaker().getATP()), address(atp));

        assertFalse(atp.getIsRevokable());

        vm.expectRevert(IATPCore.NotRevokable.selector);
        atp.getAccumulationLock();

        LATPStorage memory store = atp.getStore();

        assertEq(store.accumulationStartTime, 0);
        assertEq(store.accumulationCliffDuration, 0);
        assertEq(store.accumulationLockDuration, 0);
        assertEq(store.isRevokable, false);
        assertEq(store.revokeBeneficiary, address(0));
    }

    modifier whenRevokeBeneficiaryNEQAddressZero() {
        revokableParams.revokeBeneficiary = revokeBeneficiary;
        _;
    }

    function test_WhenRevokableLockParamsIsInvalid()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenRevokeBeneficiaryNEQAddressZero
    {
        // it reverts

        vm.expectRevert(LockLib.LockDurationMustBeGTZero.selector);
        atp.initialize(address(3), 100, revokableParams);

        revokableParams.lockParams.startTime = 0;
        revokableParams.lockParams.cliffDuration = 2;
        revokableParams.lockParams.lockDuration = 1;
        vm.expectRevert(abi.encodeWithSelector(LockLib.LockDurationMustBeGECliffDuration.selector, 1, 2));
        atp.initialize(address(3), 100, revokableParams);
    }

    function test_WhenRevokableLockParamsIsValid()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenRevokeBeneficiaryNEQAddressZero
    {
        // it updates the allocation
        // it updates the beneficiary
        // it updates the staker
        // it updates the store

        revokableParams.lockParams = LockParams({startTime: 1, cliffDuration: 2, lockDuration: 3});

        atp.initialize(address(3), 100, revokableParams);

        assertEq(atp.getAllocation(), 100);
        assertEq(atp.getBeneficiary(), address(3));
        assertNotEq(address(atp.getStaker()), address(0));
        assertEq(address(atp.getStaker().getATP()), address(atp));

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
        assertEq(store.revokeBeneficiary, revokeBeneficiary);
    }
}
