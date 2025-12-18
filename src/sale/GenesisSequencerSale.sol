// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IATPFactory} from "@atp/ATPFactory.sol";
import {INCATP} from "@atp/atps/noclaim/INCATP.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@oz/utils/ReentrancyGuard.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
import {IGenesisSequencerSale} from "./IGenesisSequencerSale.sol";

/**
 * @title GenesisSequencerSale
 * @notice A fixed-price token sale contract that creates NCATPs (must be staked after purchase) with vesting
 * @author Aztec-Labs
 * @dev Uses the ATP (Aztec Token Position - a.k.a Token Vault) system for token vesting and accepts only ETH as payment
 */
contract GenesisSequencerSale is IGenesisSequencerSale, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Constants                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The number of token purchases per address - fixed in one transaction
    uint256 public constant PURCHASES_PER_ADDRESS = 5;
    /// @notice The number of tokens per purchase
    uint256 public immutable TOKEN_LOT_SIZE;
    /// @notice The amount of sale tokens to purchase per address
    uint256 public immutable SALE_TOKEN_PURCHASE_AMOUNT;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   Notable Addresses                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The ATP factory contract address
    IATPFactory public immutable ATP_FACTORY;
    /// @notice The token that is being sold
    IERC20 public immutable SALE_TOKEN;
    /// @notice The soulbound token contract address
    IIgnitionParticipantSoulbound public immutable SOULBOUND_TOKEN;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Updatable by Admin                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The price per sequencer in ETH
    uint256 public pricePerLot;

    /// @notice The start time of the sale
    uint96 public saleStartTime;
    /// @notice The end time of the sale
    uint96 public saleEndTime;

    /// @notice Whether the sale is enabled or not
    bool public saleEnabled;

    /// @notice The screening provider
    address public addressScreeningProvider;

    /**
     * @notice Has an address already taken part in the sale
     */
    mapping(address addr => bool hasPurchased) public hasPurchased;

    /**
     * @notice Constructor
     * @param _owner The owner of the contract
     * @param _atpFactory The ATP factory contract address
     * @param _saleToken The token that is being sold
     * @param _soulboundToken The soulbound whitelist token contract address (ERC1155)
     * @param _rollup The rollup address to get activation threshold from
     * @param _pricePerLot Initial price in ETH for TOKEN_LOT_SIZE tokens
     * @param _saleStartTime Sale start timestamp
     * @param _saleEndTime Sale end timestamp
     * @param _addressScreeningProvider The address screening provider contract address
     */
    constructor(
        address _owner,
        IATPFactory _atpFactory,
        IERC20 _saleToken,
        IIgnitionParticipantSoulbound _soulboundToken,
        IStaking _rollup,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) Ownable(_owner) {
        require(
            address(_atpFactory) != address(0) && address(_soulboundToken) != address(0)
                && address(_saleToken) != address(0) && address(_rollup) != address(0),
            GenesisSequencerSale__ZeroAddress()
        );
        require(_pricePerLot > 0, GenesisSequencerSale__InvalidPrice());
        require(_saleStartTime < _saleEndTime, GenesisSequencerSale__InvalidTimeRange());
        require(_saleStartTime >= block.timestamp, GenesisSequencerSale__InvalidTimeRange());
        require(_addressScreeningProvider != address(0), GenesisSequencerSale__ZeroAddress());

        ATP_FACTORY = _atpFactory;

        TOKEN_LOT_SIZE = _rollup.getActivationThreshold();
        SALE_TOKEN_PURCHASE_AMOUNT = TOKEN_LOT_SIZE * PURCHASES_PER_ADDRESS;

        SOULBOUND_TOKEN = _soulboundToken;
        SALE_TOKEN = _saleToken;

        pricePerLot = _pricePerLot;
        emit PriceUpdated(_pricePerLot);

        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        emit SaleTimesUpdated(_saleStartTime, _saleEndTime);

        addressScreeningProvider = _addressScreeningProvider;
        emit ScreeningProviderSet(_addressScreeningProvider);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Sale Functions                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Purchase tokens SALE_TOKEN_PURCHASE_AMOUNT tokens.
     *
     * @param _atpBeneficiary The address that will receive the ATP
     *
     * @dev Requires the caller to have a soulbound token GENESIS_SEQUENCER (token ID 0)
     * @dev If you are using the same _beneficiary address for the ATP more than once, this function will fail as it will attempt to deploy to the same address.
     */
    function purchase(address _atpBeneficiary, bytes calldata _screeningData)
        external
        payable
        override(IGenesisSequencerSale)
        nonReentrant
    {
        _internalPurchase(_atpBeneficiary, _screeningData);
    }

    /**
     * @notice Purchase tokens SALE_TOKEN_PURCHASE_AMOUNT tokens.
     * @notice Forwards the data required to mint the soulbound token before calling purchase(_atpBeneficiary)
     * @notice This will result in the soulbound token being minted to the msg.sender, but the ATP will be sent to the _atpBeneficiary address
     *         there is a core invariant that person supplying the tokens holds the soulbound token, as their address is the one that is screened
     *
     * @param _atpBeneficiary The address that will receive the ATP
     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
     * @param _identityProvider The contract address of the identity screening contract - these are allowlisted by the admin
     * @param _identityData Identity data - this is the data that the identity provider will verify
     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
     * @param _gridTileId The grid tile ID that the soulbound recipient is associated with
     *
     * @dev we defer screening checks to the soulbound token contract, rather than duplicate all of the logic here, calling mint (forwarding all data)
     *      will ensure screening checks are done in the same way for everyone
     */
    function purchaseAndMintSoulboundToken(
        address _atpBeneficiary,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _soulboundRecipientScreeningData,
        bytes calldata _atpBeneficiaryScreeningData,
        uint256 _gridTileId
    ) external payable override(IGenesisSequencerSale) nonReentrant {
        SOULBOUND_TOKEN.mintFromSale(
            msg.sender,
            msg.sender,
            _merkleProof,
            _identityProvider,
            _identityData,
            _soulboundRecipientScreeningData,
            _gridTileId
        );

        // Screening has already been performed in the soulbound token check
        _internalPurchase(_atpBeneficiary, _atpBeneficiaryScreeningData);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Admin Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Enable the token sale
     *
     * @dev onlyOwner
     */
    function startSale() external override(IGenesisSequencerSale) onlyOwner {
        saleEnabled = true;
        emit SaleStarted(saleStartTime, saleEndTime);
    }

    /**
     * @notice Stop the token sale
     *
     * @dev onlyOwner
     */
    function stopSale() external override(IGenesisSequencerSale) onlyOwner {
        saleEnabled = false;
        emit SaleStopped();
    }

    /**
     * @notice Update price in ETH for TOKEN_LOT_SIZE tokens
     * @param _pricePerLot New price in ETH for TOKEN_LOT_SIZE amount
     *
     * @dev onlyOwner
     */
    function setPricePerLotInEth(uint256 _pricePerLot) external override(IGenesisSequencerSale) onlyOwner {
        require(_pricePerLot > 0, GenesisSequencerSale__InvalidPrice());
        pricePerLot = _pricePerLot;
        emit PriceUpdated(_pricePerLot);
    }

    /**
     * @notice Set the screening provider
     * @param _addressScreeningProvider The screening provider address
     *
     * @dev onlyOwner
     */
    function setAddressScreeningProvider(address _addressScreeningProvider)
        external
        override(IGenesisSequencerSale)
        onlyOwner
    {
        require(_addressScreeningProvider != address(0), GenesisSequencerSale__ZeroAddress());

        addressScreeningProvider = _addressScreeningProvider;
        emit ScreeningProviderSet(_addressScreeningProvider);
    }

    /**
     * @notice Set the sale start and end times
     * @param _saleStartTime Sale start timestamp
     * @param _saleEndTime Sale end timestamp
     *
     * @dev onlyOwner
     */
    function setSaleTimes(uint96 _saleStartTime, uint96 _saleEndTime)
        external
        override(IGenesisSequencerSale)
        onlyOwner
    {
        require(_saleStartTime < _saleEndTime, GenesisSequencerSale__InvalidTimeRange());
        require(_saleStartTime >= block.timestamp, GenesisSequencerSale__InvalidTimeRange());

        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;

        emit SaleTimesUpdated(_saleStartTime, _saleEndTime);
    }

    /**
     * @notice Withdraw tokens from the contract
     * @param _to The address to withdraw the tokens to
     * @param _token Token address to withdraw
     * @param _amount Amount to withdraw
     *
     * @dev onlyOwner
     */
    function withdrawTokens(address _to, address _token, uint256 _amount)
        external
        override(IGenesisSequencerSale)
        onlyOwner
        nonReentrant
    {
        IERC20(_token).safeTransfer(_to, _amount);
        emit TokensWithdrawn(_to, _token, _amount);
    }

    /**
     * @notice Withdraw ETH from the contract
     * @param _to The address to withdraw the ETH to
     * @param _amount Amount of ETH to withdraw
     *
     * @dev onlyOwner
     */
    function withdrawETH(address _to, uint256 _amount) external override(IGenesisSequencerSale) onlyOwner nonReentrant {
        (bool success,) = _to.call{value: _amount}("");
        require(success, GenesisSequencerSale__ETHTransferFailed());
        emit ETHWithdrawn(_to, _amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        View Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Check if the sale is active
     * @return Whether the sale is active
     */
    function isSaleActive() external view override(IGenesisSequencerSale) returns (bool) {
        return saleEnabled && block.timestamp >= saleStartTime && block.timestamp <= saleEndTime;
    }

    /**
     * @notice Get the purchase cost in ETH
     * @return The purchase cost in ETH
     */
    function getPurchaseCostInEth() public view override(IGenesisSequencerSale) returns (uint256) {
        return PURCHASES_PER_ADDRESS * pricePerLot;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Internal Functions                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Internal purchase function
     *
     * @param _beneficiary The address of the beneficiary
     * @param _beneficiaryScreeningData The screening data
     */
    function _internalPurchase(address _beneficiary, bytes memory _beneficiaryScreeningData) internal {
        // Checks
        require(saleEnabled, GenesisSequencerSale__SaleNotEnabled());
        require(block.timestamp >= saleStartTime, GenesisSequencerSale__SaleNotStarted());
        require(block.timestamp <= saleEndTime, GenesisSequencerSale__SaleHasEnded());

        // Check purchase limit
        require(!hasPurchased[msg.sender], GenesisSequencerSale__AlreadyPurchased());

        // Calculate required ETH amount
        uint256 purchaseCostInEth = getPurchaseCostInEth();
        require(msg.value == purchaseCostInEth, GenesisSequencerSale__IncorrectETH());

        // Effects
        hasPurchased[msg.sender] = true;

        // Interactions

        // Check the sender is an owner of a soulbound token GENESIS_SEQUENCER (token ID 0)
        // - Ext staticcall (view) -
        require(SOULBOUND_TOKEN.hasGenesisSequencerToken(msg.sender), GenesisSequencerSale__NoSoulboundToken());

        // If the beneficiary is the msg.sender, screening checks were performed as part of the soulbound token check
        bool performScreening = _beneficiary != msg.sender;
        if (performScreening) {
            // Perform screening
            require(
                IPredicateProvider(addressScreeningProvider).verify(_beneficiary, _beneficiaryScreeningData),
                GenesisSequencerSale__AddressScreeningFailed()
            );
        }

        // Transfer sale token from here to the ATP factory
        // - Ext call -
        // Revert conditions: will fail if the sale contract does not have enough tokens
        SALE_TOKEN.safeTransfer(address(ATP_FACTORY), SALE_TOKEN_PURCHASE_AMOUNT);

        // - Ext call -
        // Create ATP for purchaser
        INCATP atp = ATP_FACTORY.createNCATP(
            _beneficiary, // beneficiary
            SALE_TOKEN_PURCHASE_AMOUNT, // allocation
            RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        emit SaleTokensPurchased(_beneficiary, msg.sender, address(atp), purchaseCostInEth);
    }
}
