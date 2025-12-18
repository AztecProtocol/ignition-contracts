// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {SplitV2Lib} from "@splits/libraries/SplitV2.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
import {Constants} from "src/constants.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
import {BN254Lib} from "./libs/BN254.sol";
import {QueueLib, Queue} from "./libs/QueueLib.sol";

interface IStakingRegistry {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Structs                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    struct ProviderConfiguration {
        /// @notice The address of the provider admin
        address providerAdmin;
        /// @notice The take rate for the provider
        uint16 providerTakeRate;
        /// @notice The address of the provider rewards recipient
        address providerRewardsRecipient;
    }

    struct KeyStore {
        /// @notice The address of the attester
        address attester;
        /// @notice - The BLS public key - BN254 G1
        BN254Lib.G1Point publicKeyG1;
        /// @notice - The BLS public key - BN254 G2
        BN254Lib.G2Point publicKeyG2;
        /// @notice - The BLS proofOfPossession - required to prevent rogue key attacks
        BN254Lib.G1Point proofOfPossession;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event ProviderRegistered(
        uint256 indexed providerIdentifier, address indexed providerAdmin, uint16 indexed providerTakeRate
    );
    event ProviderAdminUpdateInitiated(uint256 indexed providerIdentifier, address indexed newAdmin);
    event ProviderAdminUpdated(uint256 indexed providerIdentifier, address indexed newAdmin);
    event ProviderTakeRateUpdated(uint256 indexed providerIdentifier, uint16 newTakeRate);
    event ProviderRewardsRecipientUpdated(uint256 indexed providerIdentifier, address indexed newRewardsRecipient);
    event ProviderQueueDripped(uint256 indexed providerIdentifier, address indexed attester);

    event AttestersAddedToProvider(uint256 indexed providerIdentifier, address[] attesters);

    event StakedWithProvider(
        uint256 indexed providerIdentifier,
        address indexed rollupAddress,
        address indexed attester,
        address coinbaseSplitContractAddress,
        address stakerImplementation
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error StakingRegistry__ZeroAddress();
    error StakingRegistry__InvalidProviderIdentifier(uint256 _providerIdentifier);
    error StakingRegistry__NotProviderAdmin();
    error StakingRegistry__UpdatedProviderAdminToSameAddress();
    error StakingRegistry__UpdatedProviderTakeRateToSameValue();
    error StakingRegistry__NotPendingProviderAdmin();
    error StakingRegistry__InvalidTakeRate(uint256 _takeRate);
    error StakingRegistry__UnexpectedTakeRate(uint256 _expectedTakeRate, uint256 _gotTakeRate);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Functions                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function stake(
        /// The provider identifier to stake with
        uint256 _providerIdentifier,
        /// The rollup version to stake to
        uint256 _rollupVersion,
        /// The withdrawal address for the created validator
        address _withdrawalAddress,
        /// The expected provider take rate
        uint16 _expectedProviderTakeRate,
        /// The address that will receive the rewards
        address _userRewardsRecipient,
        /// Whether to move the validator to the latest rollup
        bool _moveWithLatestRollup
    ) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                Provider Management Functions               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function registerProvider(address _providerAdmin, uint16 _providerTakeRate, address _providerRewardsRecipient)
        external
        returns (uint256);
    function addKeysToProvider(uint256 _providerIdentifier, KeyStore[] calldata _keyStores) external;
    function updateProviderAdmin(uint256 _providerIdentifier, address _newAdmin) external;
    function acceptProviderAdmin(uint256 _providerIdentifier) external;
    function updateProviderRewardsRecipient(uint256 _providerIdentifier, address _newRewardsRecipient) external;
    function updateProviderTakeRate(uint256 _providerIdentifier, uint16 _newTakeRate) external;
    function dripProviderQueue(uint256 _providerIdentifier, uint256 _numberOfKeysToDrip) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Provider Queue Getters                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function getProviderQueueLength(uint256 _providerIdentifier) external view returns (uint256);
    function getFirstIndexInQueue(uint256 _providerIdentifier) external view returns (uint128);
    function getLastIndexInQueue(uint256 _providerIdentifier) external view returns (uint128);
    function getValueAtIndexInQueue(uint256 _providerIdentifier, uint128 _index) external view returns (KeyStore memory);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       View Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function getActivationThreshold(uint256 _rollupVersion) external view returns (uint256);
}

/**
 * @title Staking Registry
 * @author Aztec-Labs
 * @notice This contract is used to register staking providers and their associated keypairs
 *
 * Description:
 * - The staking registry allows operators to list keypairs that they will run on behalf of other users.
 * - The operators are expected to have all of the keys that they list running on a validator ready to go.
 */
contract StakingRegistry is IStakingRegistry {
    using QueueLib for Queue;
    using SafeERC20 for IERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Immutables                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    PullSplitFactory public immutable PULL_SPLIT_FACTORY;
    IERC20 public immutable STAKING_ASSET;

    IRegistry public immutable ROLLUP_REGISTRY;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Storage                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    mapping(uint256 providerIdentifier => ProviderConfiguration providerConfiguration) public providerConfigurations;
    mapping(uint256 providerIdentifier => Queue attesterKeys) public providerQueues;

    /// @dev The next provider identifier to use - incremented upon each registration
    uint256 public nextProviderIdentifier = 1;

    /// @dev The provider admin waiting to accept the provider admin role
    mapping(uint256 providerIdentifier => address providerAdmin) public pendingProviderAdmins;

    constructor(IERC20 _stakingAsset, address _pullSplitFactory, IRegistry _rollupRegistry) {
        STAKING_ASSET = _stakingAsset;
        PULL_SPLIT_FACTORY = PullSplitFactory(_pullSplitFactory);
        ROLLUP_REGISTRY = _rollupRegistry;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Functions                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice stake with a provider
     *
     * Steps:
     * - Retrieve a keystore from the provider queue.
     * - Deposit into the rollup with the user's withdrawal address.
     * - Create a split contract for the user and the provider that the provider will set as the coinbase for the validator
     *   in order to split the rewards between them at a known take rate.
     *
     * - Note: The user must trust that the provider running their node will set the correct coinbase on their behalf. If you do not trust your
     *         provider to do this, do not stake with them.
     *
     * @param _providerIdentifier - The identifier of the provider to use
     * @param _rollupVersion - The rollup version to stake to
     * @param _withdrawalAddress - The address that will control withdrawing the validator
     * @param _expectedProviderTakeRate - The expected provider take rate
     * @param _userRewardsRecipient - The address that will receive the user's reward split
     * @param _moveWithLatestRollup - Whether to move the validator to the latest rollup
     */
    function stake(
        uint256 _providerIdentifier,
        uint256 _rollupVersion,
        address _withdrawalAddress,
        uint16 _expectedProviderTakeRate,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external override(IStakingRegistry) {
        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];

        // Or require providerIdentifier < nextProviderIdentifier
        require(
            providerConfiguration.providerAdmin != address(0),
            StakingRegistry__InvalidProviderIdentifier(_providerIdentifier)
        );

        require(_withdrawalAddress != address(0), StakingRegistry__ZeroAddress());
        require(_userRewardsRecipient != address(0), StakingRegistry__ZeroAddress());

        // If the provider take rate has changed inbetween the time the transaction was submitted and the time it was executed, we revert
        require(
            _expectedProviderTakeRate == providerConfiguration.providerTakeRate,
            StakingRegistry__UnexpectedTakeRate(_expectedProviderTakeRate, providerConfiguration.providerTakeRate)
        );

        address rollupAddress = ROLLUP_REGISTRY.getRollup(_rollupVersion);
        require(rollupAddress != address(0), StakingRegistry__ZeroAddress()); // Sanity check - it should never be zero

        // Revertable conditions
        // - provider has no keys - QueueIsEmpty()
        KeyStore memory keyStore = providerQueues[_providerIdentifier].dequeue();

        // This can be read from the registry!
        // Ext call - Revertable conditions
        // msg.sender does not have enough funds
        // msg.sender has not approved enough funds
        uint256 activationThreshold = IStaking(rollupAddress).getActivationThreshold();
        STAKING_ASSET.safeTransferFrom(msg.sender, address(this), activationThreshold);
        // Ext call
        STAKING_ASSET.approve(rollupAddress, activationThreshold);

        // Place the validator into the entry queue
        // Revertable conditions:
        // - attester or withdrawal address is the zero address
        // - attester is currently exiting
        //
        // Async revertable conditions: flushEntryQueue
        // - recoverable: the deposit amount will be returned to the _withdrawalAddress if the deposit fails
        IStaking(rollupAddress)
            .deposit(
                keyStore.attester,
                _withdrawalAddress,
                keyStore.publicKeyG1,
                keyStore.publicKeyG2,
                keyStore.proofOfPossession,
                _moveWithLatestRollup
            );

        // Create the splitting contract
        // User take rate is BIPS (10_000) - provider take rate
        // Provider take is constrained to be less than BIPS
        SplitV2Lib.Split memory splitInstance;
        {
            uint256 providerTakeRate = providerConfiguration.providerTakeRate;
            uint256 totalAllocation = Constants.BIPS;
            uint256 userTakeRate = totalAllocation - providerTakeRate;
            address providerRewardsRecipient = providerConfiguration.providerRewardsRecipient;

            // Set the address that will receive the rewards
            address[] memory recipients = new address[](2);
            recipients[0] = providerRewardsRecipient;
            recipients[1] = _userRewardsRecipient;

            uint256[] memory allocations = new uint256[](2);
            allocations[0] = providerTakeRate;
            allocations[1] = userTakeRate;

            splitInstance = SplitV2Lib.Split({
                recipients: recipients,
                allocations: allocations,
                totalAllocation: totalAllocation,
                distributionIncentive: 0
            });
        }

        address split = PULL_SPLIT_FACTORY.createSplit(
            splitInstance,
            address(0), // owner - 0 to make the split immutable
            address(this) // creator - only put in a log - no special permissions
        );

        emit StakedWithProvider(_providerIdentifier, rollupAddress, keyStore.attester, split, msg.sender);
    }

    /**
     * @notice Register a new staking provider
     *
     * @param _providerAdmin The address of the provider admin
     * @param _providerTakeRate The take rate for the provider
     * @param _providerRewardsRecipient The address that will receive the provider's rewards
     *
     * @dev Provider identifier's are auto-incremented and assigned to the provider
     */
    function registerProvider(address _providerAdmin, uint16 _providerTakeRate, address _providerRewardsRecipient)
        external
        override(IStakingRegistry)
        returns (uint256)
    {
        require(_providerAdmin != address(0), StakingRegistry__ZeroAddress());
        require(_providerRewardsRecipient != address(0), StakingRegistry__ZeroAddress());
        require(_providerTakeRate <= Constants.BIPS, StakingRegistry__InvalidTakeRate(_providerTakeRate));

        // Assign and increment the provider identifier
        uint256 providerIdentifier = nextProviderIdentifier;
        nextProviderIdentifier++;

        ProviderConfiguration memory providerConfiguration = ProviderConfiguration({
            providerAdmin: _providerAdmin,
            providerTakeRate: _providerTakeRate,
            providerRewardsRecipient: _providerRewardsRecipient
        });

        // Set the provider admin, queue, and take rate
        providerConfigurations[providerIdentifier] = providerConfiguration;
        providerQueues[providerIdentifier].init();

        emit ProviderRegistered(providerIdentifier, _providerAdmin, _providerTakeRate);

        return providerIdentifier;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*           Provider Queue Management Functions              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Add a set of keys to a provider
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _keyStores The key stores to add
     */
    function addKeysToProvider(uint256 _providerIdentifier, KeyStore[] calldata _keyStores)
        external
        override(IStakingRegistry)
    {
        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];

        require(msg.sender == providerConfiguration.providerAdmin, StakingRegistry__NotProviderAdmin());

        Queue storage providerQueue = providerQueues[_providerIdentifier];
        address[] memory attesters = new address[](_keyStores.length); // just for logging
        for (uint256 i; i < _keyStores.length; ++i) {
            providerQueue.enqueue(_keyStores[i]);
            attesters[i] = _keyStores[i].attester;
        }

        emit AttestersAddedToProvider(_providerIdentifier, attesters);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Provider Admin Functions                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Update the admin of a provider
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _newAdmin The new admin address
     */
    function updateProviderAdmin(uint256 _providerIdentifier, address _newAdmin) external override(IStakingRegistry) {
        address currentProviderAdmin = providerConfigurations[_providerIdentifier].providerAdmin;
        require(msg.sender == currentProviderAdmin, StakingRegistry__NotProviderAdmin());
        require(_newAdmin != address(0), StakingRegistry__ZeroAddress());
        require(_newAdmin != currentProviderAdmin, StakingRegistry__UpdatedProviderAdminToSameAddress());

        pendingProviderAdmins[_providerIdentifier] = _newAdmin;
        emit ProviderAdminUpdateInitiated(_providerIdentifier, _newAdmin);
    }

    /**
     * @notice Accept the provider admin role
     *
     * @param _providerIdentifier The identifier of the provider
     *
     * @dev The provider admin transfer can be initiated in `updateProviderAdmin` and accepted here.
     */
    function acceptProviderAdmin(uint256 _providerIdentifier) external override(IStakingRegistry) {
        require(msg.sender == pendingProviderAdmins[_providerIdentifier], StakingRegistry__NotPendingProviderAdmin());
        providerConfigurations[_providerIdentifier].providerAdmin = msg.sender;
        delete pendingProviderAdmins[_providerIdentifier];
        emit ProviderAdminUpdated(_providerIdentifier, msg.sender);
    }

    /**
     * @notice Update the rewards recipient of a provider
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _newRewardsRecipient The new rewards recipient address
     *
     * @dev The rewards recipient will be included in 0xSplits contract's deployed for the provider
     */
    function updateProviderRewardsRecipient(uint256 _providerIdentifier, address _newRewardsRecipient)
        external
        override(IStakingRegistry)
    {
        require(
            msg.sender == providerConfigurations[_providerIdentifier].providerAdmin, StakingRegistry__NotProviderAdmin()
        );

        require(_newRewardsRecipient != address(0), StakingRegistry__ZeroAddress());

        providerConfigurations[_providerIdentifier].providerRewardsRecipient = _newRewardsRecipient;
        emit ProviderRewardsRecipientUpdated(_providerIdentifier, _newRewardsRecipient);
    }

    /**
     * @notice Update the take rate of a provider
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _newTakeRate The new take rate
     *
     * @dev The take rate is a BIPS of the rewards that the provider will receive
     */
    function updateProviderTakeRate(uint256 _providerIdentifier, uint16 _newTakeRate)
        external
        override(IStakingRegistry)
    {
        require(
            msg.sender == providerConfigurations[_providerIdentifier].providerAdmin, StakingRegistry__NotProviderAdmin()
        );
        require(
            _newTakeRate != providerConfigurations[_providerIdentifier].providerTakeRate,
            StakingRegistry__UpdatedProviderTakeRateToSameValue()
        );
        require(_newTakeRate <= Constants.BIPS, StakingRegistry__InvalidTakeRate(_newTakeRate));

        providerConfigurations[_providerIdentifier].providerTakeRate = _newTakeRate;
        emit ProviderTakeRateUpdated(_providerIdentifier, _newTakeRate);
    }

    /**
     * @notice Drip the provider queue
     * If the queue gets into a bad state - e.g a provider deposits a key that is already in the rollup, or a provider deposits bad BLS keys
     * The queue can be dripped to remove the bad key.
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _numberOfKeysToDrip The number of keys to drip
     */
    function dripProviderQueue(uint256 _providerIdentifier, uint256 _numberOfKeysToDrip)
        external
        override(IStakingRegistry)
    {
        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];
        require(msg.sender == providerConfiguration.providerAdmin, StakingRegistry__NotProviderAdmin());

        Queue storage providerQueue = providerQueues[_providerIdentifier];
        for (uint256 i; i < _numberOfKeysToDrip; ++i) {
            KeyStore memory keyStore = providerQueue.dequeue();
            emit ProviderQueueDripped(_providerIdentifier, keyStore.attester);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Provider Queue Getters                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Get the length of the provider queue
     *
     * @param _providerIdentifier The identifier of the provider
     * @return The length of the provider queue
     */
    function getProviderQueueLength(uint256 _providerIdentifier)
        external
        view
        override(IStakingRegistry)
        returns (uint256)
    {
        return providerQueues[_providerIdentifier].length();
    }

    /**
     * @notice Get the first index in the provider queue
     *
     * @param _providerIdentifier The identifier of the provider
     * @return The first index in the provider queue
     */
    function getFirstIndexInQueue(uint256 _providerIdentifier)
        external
        view
        override(IStakingRegistry)
        returns (uint128)
    {
        return providerQueues[_providerIdentifier].getFirstIndex();
    }

    /**
     * @notice Get the last index in the provider queue
     *
     * @param _providerIdentifier The identifier of the provider
     * @return The last index in the provider queue
     */
    function getLastIndexInQueue(uint256 _providerIdentifier)
        external
        view
        override(IStakingRegistry)
        returns (uint128)
    {
        return providerQueues[_providerIdentifier].getLastIndex();
    }

    /**
     * @notice Get the key store at a given index in the provider queue
     *
     * @param _providerIdentifier The identifier of the provider
     * @param _index The index in the provider queue
     * @return The key store at the given index
     */
    function getValueAtIndexInQueue(uint256 _providerIdentifier, uint128 _index)
        external
        view
        override(IStakingRegistry)
        returns (KeyStore memory)
    {
        return providerQueues[_providerIdentifier].getValueAtIndex(_index);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       View Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice View function to retrieve the activation threshold for a given rollup version
     * @param _rollupVersion The version of the rollup to get the activation threshold for
     * @return The activation threshold
     */
    function getActivationThreshold(uint256 _rollupVersion) external view override(IStakingRegistry) returns (uint256) {
        address rollupAddress = ROLLUP_REGISTRY.getRollup(_rollupVersion);
        return IStaking(rollupAddress).getActivationThreshold();
    }
}
