// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";
import {EIP712} from "@oz/utils/cryptography/EIP712.sol";
import {Nonces} from "@oz/utils/Nonces.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {IWhitelistProvider} from "../soulbound/providers/IWhitelistProvider.sol";

interface IVirtualToken is IERC20 {
    function UNDERLYING_TOKEN_ADDRESS() external view returns (IERC20);
}

interface IVirtualAztecToken is IVirtualToken {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Structs                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event AuctionAddressSet(IContinuousClearingAuction auctionAddress);
    event StrategyAddressSet(address strategyAddress);
    event UnderlyingTokensRecovered(address to, uint256 amount);
    event AtpBeneficiarySet(address indexed _owner, address indexed _beneficiary);
    event ScreeningProviderSet(address indexed _screeningProvider);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error VirtualAztecToken__ZeroAddress();
    error VirtualAztecToken__Recover__InvalidAddress();
    error VirtualAztecToken__UnderlyingTokensNotBacked();
    error VirtualAztecToken__NotImplemented();
    error VirtualAztecToken__AuctionNotSet();
    error VirtualAztecToken__StrategyNotSet();
    error VirtualAztecToken__InvalidEIP712SetBeneficiarySiganture();
    error VirtualAztecToken__ScreeningFailed();
    error VirtualAztecToken__SignatureDeadlineExpired();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     User Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function setAtpBeneficiary(address _beneficiary, bytes calldata _screeningData) external;
    function setAtpBeneficiaryWithSignature(
        address _owner,
        address _beneficiary,
        uint256 _deadline,
        Signature memory _signature,
        bytes calldata _screeningData
    ) external;
    function sweepIntoAtp() external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Admin Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function mint(address _to, uint256 _amount) external;
    function setAuctionAddress(IContinuousClearingAuction _auctionAddress) external;
    function setStrategyAddress(address _strategyAddress) external;
    function pendingAtpBalance(address _beneficiary) external view returns (uint256);
    function setScreeningProvider(address _screeningProvider) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     View Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function auctionAddress() external view returns (IContinuousClearingAuction);
    function strategyAddress() external view returns (address);
    function ATP_FACTORY() external view returns (IATPFactoryNonces);
    function atpBeneficiaries(address _owner) external view returns (address);
    function getSetAtpBeneficiaryWithSignatureDigest(address _owner, address _beneficiary, uint256 _deadline, uint256 _nonce)
        external
        view
        returns (bytes32);
}

/**
 * @title Virtual Aztec Token
 * @author Aztec-Labs
 * @notice The virtual aztec token is a token used to represent the aztec token within the auction system.
 *         It is expected to hold its entire supply
 */
contract VirtualAztecToken is ERC20, EIP712, Ownable, Nonces, IVirtualAztecToken {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Constants                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice If purchasing over the stake amount - they go into a must stake ATP
    uint256 public constant MIN_STAKE_AMOUNT = 200_000 ether;

    /// @notice EIP-712 typehash for set atp beneficiary with signature
    bytes32 public constant SET_ATP_BENEFICIARY_WITH_SIGNATURE_TYPEHASH =
        keccak256("setAtpBeneficiaryWithSignature(address _owner,address _beneficiary,uint256 _deadline,uint256 _nonce)");

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Immutables                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The address of the underlying token - the aztec token
    IERC20 public immutable UNDERLYING_TOKEN_ADDRESS;

    /// @notice The address of the ATP factory contract for when not purchasing over the stake amount
    IATPFactoryNonces public immutable ATP_FACTORY;

    /// @notice The address of the foundation
    address public immutable FOUNDATION_ADDRESS;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          State                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The address of the TWAP auction contract
    IContinuousClearingAuction internal $auctionAddress;
    /// @notice The address of the launcher strategy contract
    address internal $strategyAddress;
    /// @notice Screening Provider
    address internal $screeningProvider;

    ///@notice Allow ATPs to be minted to different beneficiaries
    mapping(address owner => address beneficiary) internal $atpBeneficiaries;

    /// @notice The balances of the ATPs that have been created for each beneficiary
    mapping(address atpBeneficiary => uint256 pendingAtpBalance) internal $pendingAtpBalances;

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _underlyingTokenAddress,
        IATPFactoryNonces _atpFactory,
        address _foundationAddress
    ) ERC20(_name, _symbol) Ownable(msg.sender) EIP712("VirtualAztecToken", "1") {
        require(address(_underlyingTokenAddress) != address(0), VirtualAztecToken__ZeroAddress());
        require(address(_atpFactory) != address(0), VirtualAztecToken__ZeroAddress());
        require(address(_foundationAddress) != address(0), VirtualAztecToken__ZeroAddress());

        UNDERLYING_TOKEN_ADDRESS = _underlyingTokenAddress;
        ATP_FACTORY = _atpFactory;
        FOUNDATION_ADDRESS = _foundationAddress;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Admin Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Mint the tokens to the recipient
     * @param _to The address of the recipient
     * @param _amount The amount of tokens to mint
     * @dev Only callable by the owner
     * @dev the minter must have approved the virtual tokens contract to spend the underlying token
     * @dev the minting must be backed 1 to 1 by the underlying tokens
     */
    function mint(address _to, uint256 _amount) external override(IVirtualAztecToken) onlyOwner {
        IERC20(UNDERLYING_TOKEN_ADDRESS).transferFrom(msg.sender, address(this), _amount);

        // Check that the underlying tokens are backed 1 to 1 by the virtual tokens
        // The total supply of this token + the amount to mint should be less than or equal to the balance of the underlying held
        uint256 totalSupply = totalSupply();
        uint256 underlyingBalance = IERC20(UNDERLYING_TOKEN_ADDRESS).balanceOf(address(this));
        require(totalSupply + _amount <= underlyingBalance, VirtualAztecToken__UnderlyingTokensNotBacked());

        // Mint the tokens
        _mint(_to, _amount);
    }

    /**
     * @notice Set the auction address
     * @param _auctionAddress The address of the auction contract
     * @dev Only callable by the owner
     * @dev The auction contract is used to mint the tokens into the auction system
     */
    function setAuctionAddress(IContinuousClearingAuction _auctionAddress) external override(IVirtualAztecToken) onlyOwner {
        require(address(_auctionAddress) != address(0), VirtualAztecToken__ZeroAddress());

        $auctionAddress = _auctionAddress;
        emit AuctionAddressSet(_auctionAddress);
    }

    /**
     * @notice Set the strategy address
     * @param _strategyAddress The address of the strategy contract
     * @dev Only callable by the owner
     * @dev The strategy contract is used to migrate the tokens into the auction system
     */
    function setStrategyAddress(address _strategyAddress) external override(IVirtualAztecToken) onlyOwner {
        require(_strategyAddress != address(0), VirtualAztecToken__ZeroAddress());

        $strategyAddress = _strategyAddress;
        emit StrategyAddressSet(_strategyAddress);
    }

    /**
     * @notice Set the screening provider
     * @param _screeningProvider The address of the screening provider
     * @dev Only callable by the owner
     * @dev The screening provider is used to screen the beneficiary
     */
    function setScreeningProvider(address _screeningProvider) external override(IVirtualAztecToken) onlyOwner {
        require(_screeningProvider != address(0), VirtualAztecToken__ZeroAddress());
        $screeningProvider = _screeningProvider;
        emit ScreeningProviderSet(_screeningProvider);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      User Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Sweep the tokens into an ATP
     * @dev The tokens are swept into an ATP for the sender
     * @dev The ATP is created for the sender's beneficiary
     */
    function sweepIntoAtp() external override(IVirtualAztecToken) {
        uint256 atpBalance = $pendingAtpBalances[msg.sender];
        $pendingAtpBalances[msg.sender] = 0;

        // Create the ATP for each beneficiary
        _mintAtp(msg.sender, atpBalance);
    }

    /**
     * @notice Set the atp beneficiary
     * @param _beneficiary The address of the beneficiary
     * @dev Only callable by the owner
     * @dev The beneficiary is the address that will receive the ATPs
     */
    function setAtpBeneficiary(address _beneficiary, bytes calldata _screeningData)
        external
        override(IVirtualAztecToken)
    {
        require(_beneficiary != address(0), VirtualAztecToken__ZeroAddress());
        require(
            IWhitelistProvider($screeningProvider).verify(_beneficiary, _screeningData),
            VirtualAztecToken__ScreeningFailed()
        );

        $atpBeneficiaries[msg.sender] = _beneficiary;
        emit AtpBeneficiarySet(msg.sender, _beneficiary);
    }

    ///@notice Allow setting of the atp beneficiary via a signature in order to support multicall flows
    function setAtpBeneficiaryWithSignature(
        address _owner,
        address _beneficiary,
        uint256 _deadline,
        IVirtualAztecToken.Signature memory _signature,
        bytes calldata _screeningData
    ) external override(IVirtualAztecToken) {
        require(block.timestamp <= _deadline, VirtualAztecToken__SignatureDeadlineExpired());
        require(_owner != address(0), VirtualAztecToken__ZeroAddress());
        require(_beneficiary != address(0), VirtualAztecToken__ZeroAddress());

        uint256 nonce = _useNonce(_owner);
        bytes32 digest = getSetAtpBeneficiaryWithSignatureDigest(_owner, _beneficiary, _deadline, nonce);

        address recoveredOwner = ECDSA.recover(digest, _signature.v, _signature.r, _signature.s);
        require(recoveredOwner == _owner, VirtualAztecToken__InvalidEIP712SetBeneficiarySiganture());

        require(
            IWhitelistProvider($screeningProvider).verify(_beneficiary, _screeningData),
            VirtualAztecToken__ScreeningFailed()
        );

        $atpBeneficiaries[_owner] = _beneficiary;
        emit AtpBeneficiarySet(_owner, _beneficiary);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     View Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function auctionAddress() external view override(IVirtualAztecToken) returns (IContinuousClearingAuction) {
        return $auctionAddress;
    }

    function strategyAddress() external view override(IVirtualAztecToken) returns (address) {
        return $strategyAddress;
    }

    function pendingAtpBalance(address _beneficiary) external view override(IVirtualAztecToken) returns (uint256) {
        return $pendingAtpBalances[_beneficiary];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERC20 overrides                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Transfer the token to the recipient
     * @param _to The address of the recipient
     * @param _amount The amount of tokens to transfer
     * @return bool Whether the transfer was successful
     *
     * @dev Only implements token transfers if the sender is the auction contract or the pool migrator contract
     */
    // NOTE: there must be no circumstances where this can burn more tokens than are expected
    function transfer(address _to, uint256 _amount) public override(ERC20, IERC20) returns (bool) {
        require(address($auctionAddress) != address(0), VirtualAztecToken__AuctionNotSet());
        require(address($strategyAddress) != address(0), VirtualAztecToken__StrategyNotSet());

        if (msg.sender == address($auctionAddress) && _to == FOUNDATION_ADDRESS) {
            // Burn the virtual tokens
            _burn(msg.sender, _amount);

            // Transfer the underlying tokens back to the foundation
            return IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(_to, _amount);
        }
        // If the transfer is being made from the auction contract, it will mint an ATP for the recipient
        else if (msg.sender == address($auctionAddress)) {
            // Burn the virtual tokens
            _burn(msg.sender, _amount);

            // Account for a balance being added to the _to address for creating atp
            $pendingAtpBalances[_to] += _amount;
            return true;
        }
        // If the transfer is being made from the pool migrator contract, it will transfer the underlying tokens
        // The migrator will move the virtual tokens into the auction system at the beginning of the auction
        // So we need to check that the auction has ended in order to transfer the underlying tokens - for migration
        // be done by asserting the address it is sending to is NOT the auction address
        else if (msg.sender == $strategyAddress && _to != address($auctionAddress)) {
            // Burn the virtual tokens
            _burn(msg.sender, _amount);

            // Transfer the underlying tokens to the pool migrator
            return IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(_to, _amount);
        }

        // Otherwise, transfer the tokens normally
        return super.transfer(_to, _amount);
    }

    /**
     * @notice Transfer the tokens from the sender to the recipient
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _amount The amount of tokens to transfer
     * @return bool Whether the transfer was successful
     * @dev Reverts as transfer from is not implemented
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override(ERC20, IERC20) returns (bool) {
        if (_to == $strategyAddress) {
            return super.transferFrom(_from, _to, _amount);
        }
        revert VirtualAztecToken__NotImplemented();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     View Functions                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function getSetAtpBeneficiaryWithSignatureDigest(address _owner, address _beneficiary, uint256 _deadline, uint256 _nonce)
        public
        view
        override(IVirtualAztecToken)
        returns (bytes32)
    {
        return
            _hashTypedDataV4(keccak256(abi.encode(SET_ATP_BENEFICIARY_WITH_SIGNATURE_TYPEHASH, _owner, _beneficiary, _deadline, _nonce)));
    }

    ///@notice external view function for atp beneficiaries state mapping
    function atpBeneficiaries(address _owner) external view override(IVirtualAztecToken) returns (address) {
        return $atpBeneficiaries[_owner];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Internal Functions                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Get the atp beneficiary for the given address
    /// @dev if nothing is set, return _to, otherwise return the stored value
    function getATPBeneficiary(address _to) internal view returns (address) {
        address _storedBeneficiary = $atpBeneficiaries[_to];
        if (_storedBeneficiary != address(0)) {
            return _storedBeneficiary;
        }
        return _to;
    }

    /**
     * @notice Mint the ATP
     * @param _beneficiary The address of the beneficiary
     * @param _amount The amount of tokens to mint into the ATP
     * @dev Creates a NCATP if the amount is greater than or equal to the min stake amount, otherwise creates a LATP
     */
    function _mintAtp(address _beneficiary, uint256 _amount) internal {
        address atpBeneficiary = getATPBeneficiary(_beneficiary);

        if (_amount >= MIN_STAKE_AMOUNT) {
            // Transfer the underlying tokens to the ATP factory
            IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(address(ATP_FACTORY), _amount);
            ATP_FACTORY.createNCATP(
                atpBeneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        } else {
            // Transfer the underlying tokens to the ATP factory
            IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(address(ATP_FACTORY), _amount);
            ATP_FACTORY.createLATP(
                atpBeneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        }
    }
}
