// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";

import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

contract CannotClaim is StakerTestBase {
    address public PROVIDER_ADMIN = makeAddr("PROVIDER_ADMIN");

    uint256 public providerId;
    address public rewardsRecipient = makeAddr("rewardsRecipient");

    function setUp() public override {
        StakerTestBase.setUp();

        givenNonWithdrawableStakerIsSet();
        givenWithdrawableStakerIsSet();
        givenWithdrawableAndClaimableStakerIsSet();
    }

    function makeKeyStore(address _attester) internal pure returns (IStakingRegistry.KeyStore memory) {
        return IStakingRegistry.KeyStore({
            attester: _attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });
    }

    function test_CannotClaimIfNeverStaked(uint256 _timeJump) external givenNCATPIsSetUp {
        _timeJump = bound(_timeJump, 0, 100 * 365 days);
        vm.warp(block.timestamp + _timeJump);

        // Lazy user who never staked wants to exit
        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.StakingNotOccurred.selector));
        vm.prank(OPERATOR);
        IATPWithdrawableAndClaimableStaker(address(staker)).withdrawAllTokensToBeneficiary();
    }

    function test_CannotClaimBeforeLockUp(address _attester, uint256 _timeJump) external givenNCATPIsSetUp {
        IATPWithdrawableAndClaimableStaker istaker = IATPWithdrawableAndClaimableStaker(address(staker));
        uint256 withdrawalTimestamp = istaker.WITHDRAWAL_TIMESTAMP();
        vm.assume(withdrawalTimestamp > block.timestamp);
        _timeJump = bound(_timeJump, 0, withdrawalTimestamp - block.timestamp - 1);
        vm.warp(block.timestamp + _timeJump);

        vm.prank(OPERATOR);
        istaker.stake(
            0,
            _attester,
            BN254Lib.G1Point({x: 0, y: 0}),
            BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            BN254Lib.G1Point({x: 0, y: 0}),
            true
        );
        // Initiate Withdraw
        vm.prank(OPERATOR);
        istaker.initiateWithdraw(0, _attester);
        // Finalize Withdraw
        istaker.finalizeWithdraw(0, _attester);

        // Must not be able to withdraw
        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.WithdrawalDelayNotPassed.selector));
        vm.prank(OPERATOR);
        istaker.withdrawAllTokensToBeneficiary();
    }

    function test_CanClaimAfterStaking(address _attester) external givenNCATPIsSetUp {
        IATPWithdrawableAndClaimableStaker istaker = IATPWithdrawableAndClaimableStaker(address(staker));
        vm.prank(OPERATOR);
        istaker.stake(
            0,
            _attester,
            BN254Lib.G1Point({x: 0, y: 0}),
            BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            BN254Lib.G1Point({x: 0, y: 0}),
            true
        );

        // Initiate Withdraw
        vm.prank(OPERATOR);
        istaker.initiateWithdraw(0, _attester);

        vm.warp(istaker.WITHDRAWAL_TIMESTAMP());

        // Finalize Withdraw
        istaker.finalizeWithdraw(0, _attester);

        uint256 activationThreshold = rollup.getActivationThreshold();

        // In StakerTestBase, we only approve the staker up to one activation threshold
        // so we need to approve the staker one more activation threshold
        vm.prank(BENEFICIARY);
        userAtp.approveStaker(activationThreshold);

        uint256 beneficiaryBalanceBefore = token.balanceOf(BENEFICIARY);

        // Withdraw to beneficiary
        vm.prank(OPERATOR);
        istaker.withdrawAllTokensToBeneficiary();
        assertEq(token.balanceOf(BENEFICIARY), beneficiaryBalanceBefore + rollup.getActivationThreshold());
    }

    function test_CanClaimAfterDelegation() external givenNCATPIsSetUp {
        IATPWithdrawableAndClaimableStaker istaker = IATPWithdrawableAndClaimableStaker(address(staker));
        // Getting a provider and some keys registered into the staking registry
        providerId = stakingRegistry.registerProvider(
            PROVIDER_ADMIN,
            /*take rate*/
            10,
            rewardsRecipient
        );
        IStakingRegistry.KeyStore[] memory keyStores = new IStakingRegistry.KeyStore[](2);
        keyStores[0] = makeKeyStore(address(1));
        keyStores[1] = makeKeyStore(address(2));

        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.addKeysToProvider(providerId, keyStores);

        vm.prank(OPERATOR);
        istaker.stakeWithProvider(0, providerId, 10, BENEFICIARY, true);

        vm.prank(OPERATOR);
        istaker.initiateWithdraw(0, address(1));

        // Warp time to many years in the future
        vm.warp(block.timestamp + (10 * UNLOCK_LOCK_DURATION));

        vm.prank(OPERATOR);
        istaker.finalizeWithdraw(0, address(1));

        uint256 activationThreshold = rollup.getActivationThreshold();

        // In StakerTestBase, we only approve the staker up to one activation threshold
        // so we need to approve the staker one more activation threshold
        vm.prank(BENEFICIARY);
        userAtp.approveStaker(activationThreshold);

        uint256 beneficiaryBalanceBefore = token.balanceOf(BENEFICIARY);

        // Withdraw to beneficiary
        vm.prank(OPERATOR);
        istaker.withdrawAllTokensToBeneficiary();
        assertEq(token.balanceOf(BENEFICIARY), beneficiaryBalanceBefore + rollup.getActivationThreshold());
    }
}
