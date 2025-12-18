// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// solhint-disable imports-order
// solhint-disable comprehensive-interface

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// ATP
import {IATPPeriphery} from "@atp/atps/base/IATP.sol";
import {INCATP} from "@atp/atps/noclaim/INCATP.sol";
import {StakerVersion} from "@atp/Registry.sol";
import {IBaseStaker} from "@atp/staker/BaseStaker.sol";

// Staker
import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// Libs
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

/**
 * @title Upgraded Staker Implementation
 * @notice A mock upgraded version of the staker to test upgradeability
 * @dev This adds a new storage variable to demonstrate safe upgradeability
 */
contract UpgradedATPWithdrawableAndClaimableStaker is ATPWithdrawableAndClaimableStaker {
    /**
     * @custom:storage-location erc7201:aztec.storage.ATPWithdrawableAndClaimableStaker.Upgraded
     */
    struct UpgradedATPWithdrawableAndClaimableStakerStorage {
        /**
         * @notice New feature flag for testing upgrades
         */
        bool newFeatureEnabled;
    }

    // keccak256(abi.encode(uint256(keccak256("aztec.storage.ATPWithdrawableAndClaimableStaker.Upgraded")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _UPGRADED_ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE =
        0x4032a24c2a48681ee37801a32530693ecb3510ba40548c2105ca7effc10ce900;

    constructor(
        IERC20 _stakingAsset,
        IRegistry _rollupRegistry,
        IStakingRegistry _stakingRegistry,
        uint256 _withdrawalTimestamp
    ) ATPWithdrawableAndClaimableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry, _withdrawalTimestamp) {}

    /**
     * @notice Enable the new feature
     * @dev Only callable by operator to test that upgrades work correctly
     */
    function enableNewFeature() external onlyOperator {
        UpgradedATPWithdrawableAndClaimableStakerStorage storage $ =
            _getUpgradedATPWithdrawableAndClaimableStakerStorage();
        $.newFeatureEnabled = true;
    }

    /**
     * @notice Check if new feature is enabled
     * @return bool indicating whether the new feature is enabled
     */
    function isNewFeatureEnabled() external view returns (bool) {
        UpgradedATPWithdrawableAndClaimableStakerStorage storage $ =
            _getUpgradedATPWithdrawableAndClaimableStakerStorage();
        return $.newFeatureEnabled;
    }

    /**
     * @dev Returns a pointer to the upgraded storage namespace.
     */
    function _getUpgradedATPWithdrawableAndClaimableStakerStorage()
        private
        pure
        returns (UpgradedATPWithdrawableAndClaimableStakerStorage storage $)
    {
        assembly {
            $.slot := _UPGRADED_ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE
        }
    }
}

/**
 * @title Upgrade Staker Test
 * @notice Tests the upgradeability of ATPWithdrawableAndClaimableStaker
 */
contract UpgradeStakerTest is StakerTestBase {
    INCATP public atp;
    address public attester = makeAddr("attester");

    function setUp() public override(StakerTestBase) {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
        givenWithdrawableStakerIsSet();
        givenWithdrawableAndClaimableStakerIsSet();
    }

    /**
     * @notice Test that storage is preserved across upgrades
     * @dev Stakes, upgrades, then verifies withdrawable flag is still set
     */
    function test_StoragePreservedAcrossUpgrade() public {
        // Create ATP and setup
        atp = INCATP(address(givenUserNCAtp(BENEFICIARY, rollup.getActivationThreshold())));

        vm.prank(BENEFICIARY);
        atp.updateStakerOperator(OPERATOR);

        // Get staker and upgrade to withdrawable and claimable
        IBaseStaker stakerProxy = IATPPeriphery(address(atp)).getStaker();
        vm.prank(BENEFICIARY);
        atp.upgradeStaker(StakerVersion.wrap(WITHDRAWABLE_AND_CLAIMABLE_STAKER_VERSION));

        // Allow ATP to make allowances to the staker
        atpRegistry.setExecuteAllowedAt(block.timestamp);

        uint256 activationThreshold = rollup.getActivationThreshold();
        vm.prank(BENEFICIARY);
        atp.approveStaker(activationThreshold);

        // Stake to set withdrawable flag
        vm.prank(OPERATOR);
        IATPWithdrawableAndClaimableStaker(address(stakerProxy))
            .stake(
                0,
                attester,
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );

        // Verify withdrawable is true before upgrade
        assertEq(ATPWithdrawableAndClaimableStaker(address(stakerProxy)).hasStaked(), true);

        // Register and perform upgrade
        UpgradedATPWithdrawableAndClaimableStaker upgradedStaker =
            new UpgradedATPWithdrawableAndClaimableStaker(token, rollupRegistry, stakingRegistry, block.timestamp + 365 days);
        atpRegistry.registerStakerImplementation(address(upgradedStaker));
        StakerVersion newVersion = atpRegistry.getNextStakerVersion();
        newVersion = StakerVersion.wrap(StakerVersion.unwrap(newVersion) - 1);

        vm.prank(BENEFICIARY);
        atp.upgradeStaker(newVersion);

        // Verify withdrawable is still true after upgrade
        assertEq(ATPWithdrawableAndClaimableStaker(address(stakerProxy)).hasStaked(), true);

        // Verify new feature is initially false
        assertEq(UpgradedATPWithdrawableAndClaimableStaker(address(stakerProxy)).isNewFeatureEnabled(), false);

        // Enable new feature
        vm.prank(OPERATOR);
        UpgradedATPWithdrawableAndClaimableStaker(address(stakerProxy)).enableNewFeature();

        // Verify new feature is now enabled
        assertEq(UpgradedATPWithdrawableAndClaimableStaker(address(stakerProxy)).isNewFeatureEnabled(), true);

        // Verify original storage is still intact
        assertEq(ATPWithdrawableAndClaimableStaker(address(stakerProxy)).hasStaked(), true);
    }
}
