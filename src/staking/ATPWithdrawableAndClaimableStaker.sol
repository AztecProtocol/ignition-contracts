// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IATPCore} from "@atp/atps/base/IATP.sol";
import {NCATP} from "@atp/atps/noclaim/NCATP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";

/**
 * @title ATP Withdrawable And Claimable Staker
 * @author Aztec-Labs
 * @notice An implementation of an ATP Staker that allows for withdrawals from the rollup
 *         and enables NCATP token holders to claim tokens only after staking has occured.
 */
contract ATPWithdrawableAndClaimableStaker is IATPWithdrawableAndClaimableStaker, ATPWithdrawableStaker {
    using SafeERC20 for IERC20;

    /**
     * @dev Storage of the ATPWithdrawableAndClaimableStaker contract.
     *
     * @custom:storage-location erc7201:aztec.storage.ATPWithdrawableAndClaimableStaker
     */
    struct ATPWithdrawableAndClaimableStakerStorage {
        /**
         * @notice Flag indicating whether staking has occured
         */
        bool hasStaked;
    }

    // keccak256(abi.encode(uint256(keccak256("aztec.storage.ATPWithdrawableAndClaimableStaker")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE =
        0x2527cfd5830db0c841b72084c1ec066be32b8320e2ee2b8cb438bb32af8d8500;

    /**
     * @notice The timestamp at which withdrawals are enabled.
     */
    uint256 public immutable WITHDRAWAL_TIMESTAMP;

    /**
     * @notice Emitted when tokens are withdrawn by NCATP holders
     * @param recipient The address receiving the tokens
     * @param amount The amount of tokens withdrawn
     */
    event TokensWithdrawn(address indexed recipient, uint256 amount);

    /**
     * @notice Emitted when withdrawable status changes
     */
    event WithdrawableStatusChanged();

    /**
     * @notice Emitted when tokens are withdrawn to the beneficiary
     * @param beneficiary The address of the ATP beneficiary
     * @param amount The amount of tokens withdrawn
     */
    event TokensWithdrawnToBeneficiary(address indexed beneficiary, uint256 amount);

    /**
     * @notice Error thrown when attempting to withdraw before staking has occurred
     */
    error StakingNotOccurred();

    /**
     * @notice Error thrown when attempting to withdraw before the withdrawal delay has passed
     */
    error WithdrawalDelayNotPassed();

    constructor(
        IERC20 _stakingAsset,
        IRegistry _rollupRegistry,
        IStakingRegistry _stakingRegistry,
        uint256 _withdrawalTimestamp
    ) ATPWithdrawableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry) {
        WITHDRAWAL_TIMESTAMP = _withdrawalTimestamp;
    }

    /**
     * @notice Stake the staking asset to the rollup
     * @dev Overrides the parent stake function to set withdrawable to true after successful staking
     *
     * @param _version The version of the rollup to deposit to
     * @param _attester The address of the attester on the rollup
     * @param _publicKeyG1 The public key of the attester - BN254Lib.G1Point
     * @param _publicKeyG2 The public key of the attester - BN254Lib.G2Point
     * @param _signature The signature of the attester - BN254Lib.G1Point
     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
     *
     * @dev If _moveWithLatestRollup is true, then the rollup version MUST be the latest version
     * @dev Requires atp.approveStaker() has been called before
     */
    function stake(
        uint256 _version,
        address _attester,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithLatestRollup
    ) external override(ATPNonWithdrawableStaker, IATPNonWithdrawableStaker) onlyOperator {
        // Call parent stake function
        _stake(_version, _attester, _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);

        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
        if (!$.hasStaked) {
            $.hasStaked = true;
            emit WithdrawableStatusChanged();
        }
    }

    /**
     * @notice Stake with a provider
     * @dev Overrides the parent stakeWithProvider function to set withdrawable to true after successful delegation
     *
     * @param _version The version of the rollup to deposit to
     * @param _providerIdentifier The identifier of the provider to stake wit
     * @param _expectedProviderTakeRate The expected provider take rate
     * @param _userRewardsRecipient The address that will receive the user's reward split
     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
     */
    function stakeWithProvider(
        uint256 _version,
        uint256 _providerIdentifier,
        uint16 _expectedProviderTakeRate,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external override(ATPNonWithdrawableStaker, IATPNonWithdrawableStaker) onlyOperator {
        // Call parent stakeWithProvider function
        _stakeWithProvider(
            _version, _providerIdentifier, _expectedProviderTakeRate, _userRewardsRecipient, _moveWithLatestRollup
        );

        // Set withdrawable to true after successful staking
        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
        if (!$.hasStaked) {
            $.hasStaked = true;
            emit WithdrawableStatusChanged();
        }
    }

    /**
     * @notice Withdraw all available tokens to the beneficiary
     * @dev Only callable if staking has occurred (withdrawable == true)
     */
    function withdrawAllTokensToBeneficiary() external override(IATPWithdrawableAndClaimableStaker) onlyOperator {
        address atp = getATP();

        require(hasStaked(), StakingNotOccurred());
        require(block.timestamp >= WITHDRAWAL_TIMESTAMP, WithdrawalDelayNotPassed());

        uint256 atpBalance = STAKING_ASSET.balanceOf(atp);

        address beneficiary = IATPCore(atp).getBeneficiary();

        if (atpBalance > 0) {
            STAKING_ASSET.safeTransferFrom(atp, beneficiary, atpBalance);
            emit TokensWithdrawnToBeneficiary(beneficiary, atpBalance);
        }
    }

    /**
     * @notice Returns the hasStaked flag
     * @return bool indicating whether staking has occurred
     */
    function hasStaked() public view override(IATPWithdrawableAndClaimableStaker) returns (bool) {
        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
        return $.hasStaked;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    function _getATPWithdrawableAndClaimableStakerStorage()
        private
        pure
        returns (ATPWithdrawableAndClaimableStakerStorage storage $)
    {
        assembly {
            $.slot := _ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE
        }
    }
}
