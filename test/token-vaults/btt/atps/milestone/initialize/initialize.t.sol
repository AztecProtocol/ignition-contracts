// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Initializable} from "@oz/proxy/utils/Initializable.sol";
import {Clones} from "@oz/proxy/Clones.sol";

import {
    MATP,
    IRegistry,
    LockParams,
    Lock,
    LockLib,
    IATPCore,
    RevokableParams,
    StakerVersion,
    MilestoneId,
    MilestoneStatus
} from "test/token-vaults/Importer.sol";

contract InitializeTest is MATPTestBase {
    MATP internal implementation;
    MATP internal atp;

    MilestoneId internal milestoneId;

    function setUp() public override {
        super.setUp();

        implementation = new MATP(registry, token);
        atp = MATP(Clones.clone(address(implementation)));
    }

    function test_whenTryingToInitializeImplementation() external {
        milestoneId = registry.addMilestone();
        vm.expectRevert(abi.encodeWithSelector(IATPCore.AlreadyInitialized.selector));
        implementation.initialize(address(3), 100, milestoneId);
    }

    function test_GivenAlreadyInitialize() external {
        // it reverts
        milestoneId = registry.addMilestone();
        atp.initialize(address(3), 100, milestoneId);

        vm.expectRevert(abi.encodeWithSelector(IATPCore.AlreadyInitialized.selector));
        atp.initialize(address(3), 100, milestoneId);
    }

    modifier givenStakerEQAddressZero() {
        _;
    }

    function test_GivenBeneficiaryEQAddressZero() external givenStakerEQAddressZero {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidBeneficiary.selector, address(0)));
        atp.initialize(address(0), 100, milestoneId);
    }

    modifier givenBeneficiaryNEQAddressZero() {
        _;
    }

    function test_GivenAllocationEQ0() external givenStakerEQAddressZero givenBeneficiaryNEQAddressZero {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IATPCore.AllocationMustBeGreaterThanZero.selector));
        atp.initialize(address(3), 0, milestoneId);
    }

    modifier givenAllocationGT0() {
        _;
    }

    function test_WhenMilestoneNotExists()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
    {
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneId.selector, MilestoneId.wrap(100)));
        atp.initialize(address(3), 100, MilestoneId.wrap(100));
    }

    modifier whenMilestoneExists() {
        milestoneId = registry.addMilestone();
        _;
    }

    function test_GivenMilestoneNeqPending(uint256 _status)
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenMilestoneExists
    {
        // it reverts
        MilestoneStatus status = MilestoneStatus(bound(_status, 1, 2));
        registry.setMilestoneStatus(milestoneId, status);

        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneStatus.selector, milestoneId));
        atp.initialize(address(3), 100, milestoneId);
    }

    function test_GivenMilestoneEqPending()
        external
        givenStakerEQAddressZero
        givenBeneficiaryNEQAddressZero
        givenAllocationGT0
        whenMilestoneExists
    {
        // it updates the allocation
        // it updates the beneficiary
        // it updates the staker
        // it updates the milestone id

        atp.initialize(address(3), 100, milestoneId);

        assertEq(atp.getAllocation(), 100);
        assertEq(atp.getBeneficiary(), address(3));
        assertEq(atp.getStaker().getImplementation(), registry.getStakerImplementation(StakerVersion.wrap(0)));
        assertNotEq(address(atp.getStaker()), address(0));
        assertEq(address(atp.getStaker().getATP()), address(atp));
        assertTrue(atp.getIsRevokable());
        assertFalse(atp.getIsRevoked());
        assertEq(MilestoneId.unwrap(atp.getMilestoneId()), MilestoneId.unwrap(milestoneId));
    }
}
