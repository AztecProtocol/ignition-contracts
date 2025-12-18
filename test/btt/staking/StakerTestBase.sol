// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ATPFactory} from "@atp/ATPFactory.sol";
import {IRegistry} from "@atp/Registry.sol";
import {MockRollup} from "test/mocks/staking/MockRollup.sol";
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";
import {MockGovernance} from "test/mocks/staking/MockGovernance.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {IATPCore} from "@atp/atps/base/IATP.sol";
import {ILATP} from "@atp/atps/linear/ILATP.sol";
import {INCATP} from "@atp/atps/noclaim/INCATP.sol";
import {RevokableParams} from "@atp/ATPFactory.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";
import {IATPPeriphery} from "@atp/atps/base/IATP.sol";
import {IBaseStaker} from "@atp/staker/BaseStaker.sol";
import {StakerVersion} from "@atp/Registry.sol";

import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";

import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
import {SplitsWarehouse} from "@splits/SplitsWarehouse.sol";

import {Constants} from "src/constants.sol";

abstract contract StakerTestBase is Test {
    // Mock token
    IERC20 public token;

    // Mock rollup
    MockGovernance public governance;
    MockRollup public rollup;
    MockGSE public gse;
    MockRegistry public rollupRegistry;

    // ATP factory and registry
    ATPFactory public factory;
    IRegistry public atpRegistry;

    // Staking registry
    IStakingRegistry public stakingRegistry;

    // Staker implementations
    IATPNonWithdrawableStaker public nonWithdrawableStaker;
    IATPWithdrawableStaker public withdrawableStaker;
    IATPWithdrawableAndClaimableStaker public withdrawableAndClaimableStaker;

    uint256 public constant UNLOCK_CLIFF_DURATION = 182 days;
    uint256 public constant UNLOCK_LOCK_DURATION = 365 days;

    address public BENEFICIARY = makeAddr("beneficiary");
    address public OPERATOR = makeAddr("operator");

    IATPCore userAtp;
    IBaseStaker staker;

    uint256 public NON_WITHDRAWABLE_STAKER_VERSION = 1;
    uint256 public WITHDRAWABLE_STAKER_VERSION = 2;
    uint256 public WITHDRAWABLE_AND_CLAIMABLE_STAKER_VERSION = 3;

    modifier givenATPIsSetUp() {
        userAtp = givenUserAtp(BENEFICIARY, rollup.getActivationThreshold());

        // Get the address of the staker
        staker = IATPPeriphery(address(userAtp)).getStaker();

        vm.prank(BENEFICIARY);
        userAtp.updateStakerOperator(OPERATOR);
        vm.prank(BENEFICIARY);
        userAtp.upgradeStaker(StakerVersion.wrap(NON_WITHDRAWABLE_STAKER_VERSION));

        atpRegistry.setExecuteAllowedAt(block.timestamp + UNLOCK_CLIFF_DURATION);
        vm.warp(block.timestamp + UNLOCK_CLIFF_DURATION + 1);

        uint256 activationThreshold = rollup.getActivationThreshold();

        vm.prank(BENEFICIARY);
        userAtp.approveStaker(activationThreshold);
        _;
    }

    modifier givenNCATPIsSetUp() {
        userAtp = givenUserNCAtp(BENEFICIARY, rollup.getActivationThreshold());

        // Get the address of the staker
        staker = IATPPeriphery(address(userAtp)).getStaker();

        vm.prank(BENEFICIARY);
        userAtp.updateStakerOperator(OPERATOR);
        vm.prank(BENEFICIARY);
        userAtp.upgradeStaker(StakerVersion.wrap(WITHDRAWABLE_AND_CLAIMABLE_STAKER_VERSION));

        atpRegistry.setExecuteAllowedAt(block.timestamp);

        uint256 activationThreshold = rollup.getActivationThreshold();

        vm.prank(BENEFICIARY);
        userAtp.approveStaker(activationThreshold);
        _;
    }

    modifier givenATPIsSetUpForWithdrawableStaker() {
        upgradeToWithdrawableStaker();
        _;
    }

    modifier givenATPIsSetUpForWithdrawableAndClaimableStaker() {
        upgradeToWithdrawableAndClaimableStaker();
        _;
    }

    function setUp() public virtual {
        token = new MockERC20("Token", "TKN");
        gse = new MockGSE();
        rollup = new MockRollup(token, gse);

        gse.addRollup(address(rollup));
        governance = new MockGovernance(address(token));
        rollupRegistry = new MockRegistry(address(governance));
        rollupRegistry.addRollup(0, address(rollup));

        SplitsWarehouse splitsWarehouse = new SplitsWarehouse("eth", "eth");
        PullSplitFactory pullSplitFactory = new PullSplitFactory(address(splitsWarehouse));

        stakingRegistry = new StakingRegistry(token, address(pullSplitFactory), rollupRegistry);

        factory = new ATPFactory(address(this), token, UNLOCK_CLIFF_DURATION, UNLOCK_LOCK_DURATION);
        factory.setMinter(address(this), true);

        // Fund ATP factory
        MockERC20(address(token)).mint(address(factory), 100_000_000 ether);

        // The constructor of the atpFactory will create a registry which is
        // owned by the deployer of the factory - address(this)
        atpRegistry = factory.getRegistry();

        // Create the staker implementations
        nonWithdrawableStaker = new ATPNonWithdrawableStaker(token, rollupRegistry, stakingRegistry);
        withdrawableStaker = new ATPWithdrawableStaker(token, rollupRegistry, stakingRegistry);
        withdrawableAndClaimableStaker =
            new ATPWithdrawableAndClaimableStaker(token, rollupRegistry, stakingRegistry, block.timestamp + 365 days);
    }

    function givenNonWithdrawableStakerIsSet() public {
        assertEq(StakerVersion.unwrap(atpRegistry.getNextStakerVersion()), NON_WITHDRAWABLE_STAKER_VERSION);
        atpRegistry.registerStakerImplementation(address(nonWithdrawableStaker));
    }

    function givenWithdrawableStakerIsSet() public {
        assertEq(StakerVersion.unwrap(atpRegistry.getNextStakerVersion()), WITHDRAWABLE_STAKER_VERSION);
        atpRegistry.registerStakerImplementation(address(withdrawableStaker));
    }

    function givenWithdrawableAndClaimableStakerIsSet() public {
        assertEq(StakerVersion.unwrap(atpRegistry.getNextStakerVersion()), WITHDRAWABLE_AND_CLAIMABLE_STAKER_VERSION);
        atpRegistry.registerStakerImplementation(address(withdrawableAndClaimableStaker));
    }

    function upgradeToWithdrawableStaker() public {
        vm.prank(BENEFICIARY);
        userAtp.upgradeStaker(StakerVersion.wrap(WITHDRAWABLE_STAKER_VERSION));
    }

    function upgradeToWithdrawableAndClaimableStaker() public {
        vm.prank(BENEFICIARY);
        userAtp.upgradeStaker(StakerVersion.wrap(WITHDRAWABLE_AND_CLAIMABLE_STAKER_VERSION));
    }

    function givenUserAtp(address _beneficiary, uint256 _stakeAmount) public returns (IATPCore) {
        // Create a new ATP
        ILATP atp = factory.createLATP(
            _beneficiary, _stakeAmount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        return IATPCore(address(atp));
    }

    function givenUserNCAtp(address _beneficiary, uint256 _stakeAmount) public returns (IATPCore) {
        // Create a new NCATP
        INCATP atp = factory.createNCATP(
            _beneficiary, _stakeAmount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        return IATPCore(address(atp));
    }
}
