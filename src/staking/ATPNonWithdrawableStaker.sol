// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {BaseStaker} from "@atp/staker/BaseStaker.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {IATPNonWithdrawableStaker, IGovernanceATP} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IGovernance, IPayload} from "src/staking/rollup-system-interfaces/IGovernance.sol";
import {IGSE} from "src/staking/rollup-system-interfaces/IGSE.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";

/**
 * @title ATP Staker
 * @author Aztec-Labs
 * @notice Stake from an ATP to earn rewards
 *
 * @notice NonWithdrawableStaker does not implement the withdrawal functionality, this will be enabled in an upgrade to the staker contract
 *         At the time of ignition, Aligned Stakers are expected to stake until their position is withdrawable.
 */

contract ATPNonWithdrawableStaker is IATPNonWithdrawableStaker, BaseStaker {
    using SafeERC20 for IERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event Staked(address indexed staker, address indexed attester, address indexed rollupAddress);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Immutables                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    IERC20 public immutable STAKING_ASSET;
    IRegistry public immutable ROLLUP_REGISTRY;
    IStakingRegistry public immutable STAKING_REGISTRY;

    constructor(IERC20 _stakingAsset, IRegistry _rollupRegistry, IStakingRegistry _stakingRegistry) {
        STAKING_ASSET = _stakingAsset;
        ROLLUP_REGISTRY = _rollupRegistry;
        STAKING_REGISTRY = _stakingRegistry;
    }

    /**
     * @notice Stake the staking asset to the rollup
     *
     * Withdrawer is set to this contract address
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
    ) external virtual override(IATPNonWithdrawableStaker) onlyOperator {
        _stake(_version, _attester, _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);
    }

    /**
     * @notice Stake with a provider
     *
     * A provider is an external operator that has registered themselves with the staking provider registry
     * When using the staking registry
     * - providers register themselves with a given take rate for their services
     * - the attester field, is requested from a list of keys that the provider has listed
     * - the stake function on the registry performs staking, creating a fee splitting contract for rewards to go into
     *
     * @param _version The version of the rollup to deposit to
     * @param _providerIdentifier The identifier of the provider to stake with
     * @param _expectedProviderTakeRate The expected provider take rate
     * @param _userRewardsRecipient The address that will receive the user's reward split
     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
     *
     * @dev Requires atp.approveStaker() has been called before
     */
    function stakeWithProvider(
        uint256 _version,
        uint256 _providerIdentifier,
        uint16 _expectedProviderTakeRate,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external virtual override(IATPNonWithdrawableStaker) onlyOperator {
        _stakeWithProvider(
            _version, _providerIdentifier, _expectedProviderTakeRate, _userRewardsRecipient, _moveWithLatestRollup
        );
    }

    /**
     * @notice If and only if the atp is set as the coinbase for the active validator, then rewards will need to be claimed
     * from the rollup
     *
     * @param _version The version of the rollup to claim rewards from
     */
    function claimRewards(uint256 _version) external override(IATPNonWithdrawableStaker) onlyOperator {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        address atp = getATP();

        IStaking(rollup).claimSequencerRewards(atp);
    }

    /**
     * @notice delegate voting power to a delegatee
     * @notice By default voting power is delegated to the rollup itself, with validators determining
     * what proposals will get voted on. This means most users will not need to delegate their vote if they
     * are staking.
     *
     * @dev this function only requires to delegating staked tokens
     *      use depositIntoGovernance to vote with unstaked tokens
     *
     * @param _version The version of the rollup to delegate to
     * @param _attester The address of the attester the voting power is associated with on the rollup
     * @param _delegatee The address of the delegatee
     */
    function delegate(uint256 _version, address _attester, address _delegatee)
        external
        virtual
        override(IATPNonWithdrawableStaker)
        onlyOperator
    {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        address gse = IStaking(rollup).getGSE();

        IGSE(gse).delegate(rollup, _attester, _delegatee);
    }

    /**
     * @notice Deposit tokens into governance for voting
     * @notice This staker contract becomes the beneficiary and holder of voting power
     *         voting must take place through the voteInGovernance function
     *
     * @dev Governance contract is derived from the rollup registry
     *
     * @param _amount The amount of tokens to deposit into governance
     */
    function depositIntoGovernance(uint256 _amount) external override(IGovernanceATP) onlyOperator {
        address governance = ROLLUP_REGISTRY.getGovernance();

        STAKING_ASSET.safeTransferFrom(address(atp), address(this), _amount);
        STAKING_ASSET.approve(address(governance), _amount);
        IGovernance(governance).deposit(address(this), _amount);
    }

    /**
     * @notice Vote in governance
     * @notice Voting power is held by this staker contract
     *         Users must first deposit into Goverance via depositIntoGovernance first
     *
     * @dev Governance contract is derived from the rollup registry
     *
     * @param _proposalId The ID of the proposal to vote on
     * @param _amount The amount of tokens to vote with
     * @param _support The support for the proposal
     */
    function voteInGovernance(uint256 _proposalId, uint256 _amount, bool _support)
        external
        override(IGovernanceATP)
        onlyOperator
    {
        address governance = ROLLUP_REGISTRY.getGovernance();
        IGovernance(governance).vote(_proposalId, _amount, _support);
    }

    /**
     * @notice Initiate a withdrawal from governance
     * @notice This function will initiate a withdrawal from governance
     *         Users must first deposit into Goverance via depositIntoGovernance first
     *
     * @dev Governance contract is derived from the rollup registry
     *
     * @param _amount The amount of tokens to withdraw from governance
     * @return The withdrawal ID - this must be used when calling finalizeWithdraw on the Governance contract
     */
    function initiateWithdrawFromGovernance(uint256 _amount)
        external
        override(IGovernanceATP)
        onlyOperator
        returns (uint256)
    {
        address governance = ROLLUP_REGISTRY.getGovernance();
        address atp = getATP();

        return IGovernance(governance).initiateWithdraw(atp, _amount);
    }

    /**
     * @notice Propose With Lock
     * @notice This function will make a proposal into Goverance but funds will be locked for an
     *         extended period of time - see the Gov implementation for more details
     *
     * @param _proposal The proposal to propose
     * @return The proposal ID
     */
    function proposeWithLock(IPayload _proposal) external override(IGovernanceATP) onlyOperator returns (uint256) {
        address governance = ROLLUP_REGISTRY.getGovernance();
        address atp = getATP();

        return IGovernance(governance).proposeWithLock(_proposal, atp);
    }

    /**
     * @notice Move the funds back to the ATP
     *
     * Case in which this is required:
     * - When calling deposit with _moveWithLatestRollup set to true, the staker will enter the deposit queue
     * - If user gets to the front of the queue, but the rollup has been upgraded, _moveWithLatestRollup will be invalid
     * - This will return the funds to the withdrawer (this address)
     * - This leaves the user to perform the following steps:
     *   - return the funds back to the atp
     *   - then call stake again on the updated rollup version
     *
     * @dev This function is only callable by the operator
     * @dev This function will move the funds back to the ATP ONLY
     */
    function moveFundsBackToATP() external override(IATPNonWithdrawableStaker) onlyOperator {
        address atp = getATP();
        uint256 balance = STAKING_ASSET.balanceOf(address(this));

        STAKING_ASSET.safeTransfer(atp, balance);
    }

    function _stake(
        uint256 _version,
        address _attester,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithLatestRollup
    ) internal virtual onlyOperator {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        uint256 activationThreshold = IStaking(rollup).getActivationThreshold();

        STAKING_ASSET.safeTransferFrom(address(atp), address(this), activationThreshold);
        STAKING_ASSET.approve(rollup, activationThreshold);
        IStaking(rollup)
            .deposit(_attester, address(this), _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);

        emit Staked(address(this), _attester, rollup);
    }

    function _stakeWithProvider(
        uint256 _version,
        uint256 _providerIdentifier,
        uint16 _expectedProviderTakeRate,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) internal virtual onlyOperator {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        uint256 activationThreshold = IStaking(rollup).getActivationThreshold();

        STAKING_ASSET.safeTransferFrom(address(atp), address(this), activationThreshold);
        STAKING_ASSET.approve(address(STAKING_REGISTRY), activationThreshold);
        STAKING_REGISTRY.stake(
            _providerIdentifier,
            _version,
            address(this),
            _expectedProviderTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );
    }
}
