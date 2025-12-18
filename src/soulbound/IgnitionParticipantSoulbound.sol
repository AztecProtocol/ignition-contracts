// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";
import {ERC1155, IERC1155} from "@oz/token/ERC1155/ERC1155.sol";
import {MerkleProof} from "@oz/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@oz/utils/ReentrancyGuard.sol";
import {IIgnitionParticipantSoulbound} from "./IIgnitionParticipantSoulbound.sol";
import {IWhitelistProvider} from "./providers/IWhitelistProvider.sol";

/**
 * @title IgnitionParticipantSoulbound
 * @notice A soulbound ERC1155 token used for whitelist access control
 * @dev Token ID 0: For Genesis Sequencer users
 *      Token ID 1: For Contributor users
 *      Token ID 2: For general de-risked users
 *      Tokens cannot be transferred once minted, making them "soulbound" to the recipient
 */
contract IgnitionParticipantSoulbound is IIgnitionParticipantSoulbound, ERC1155, Ownable, ReentrancyGuard {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       State Variables                      */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /// Merkle root for privileged whitelists
    /// @dev Gating for Token ID 0
    bytes32 public genesisSequencerMerkleRoot;
    /// @dev Gating for Token ID 1
    bytes32 public contributorMerkleRoot;

    /// Whitelist providers
    /// @dev Whitelist providers for general whitelist
    mapping(address provider => bool active) public identityProviders;

    /// @dev Provider for address screening
    address public addressScreeningProvider;

    /// @dev Track if an address has minted (can only mint once)
    mapping(address addr => bool hasMinted) public hasMinted;

    /// @dev Track the grid token ID for each address
    mapping(address soulboundRecipient => uint256 gridTileId) public gridTileId;
    /// @dev Track if a grid tile ID has been assigned
    mapping(uint256 gridTileId => bool isAssigned) public isGridTileIdAssigned;

    /// @dev Address of the token sale contract
    address public tokenSaleAddress;

    constructor(
        address _tokenSaleAddress,
        address[] memory _identityProviders,
        bytes32 _genesisSequencerMerkleRoot,
        bytes32 _contributorMerkleRoot,
        address _addressScreeningProvider,
        string memory _uri
    ) ERC1155(_uri) Ownable(msg.sender) {
        tokenSaleAddress = _tokenSaleAddress;
        // Set the initial whitelist providers
        for (uint256 i = 0; i < _identityProviders.length; i++) {
            identityProviders[_identityProviders[i]] = true;
            emit IdentityProviderSet(_identityProviders[i], true);
        }

        addressScreeningProvider = _addressScreeningProvider;
        emit AddressScreeningProviderSet(_addressScreeningProvider);

        genesisSequencerMerkleRoot = _genesisSequencerMerkleRoot;
        emit GenesisSequencerMerkleRootUpdated(_genesisSequencerMerkleRoot);

        contributorMerkleRoot = _contributorMerkleRoot;
        emit ContributorMerkleRootUpdated(_contributorMerkleRoot);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Mint Functions                        */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /**
     * @notice Mint an IgnitionParticipant token to an address
     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
     * @param _soulboundRecipient The address of the soulbound recipient
     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
     * @param _identityData Identity data - this is the data that the identity provider will verify
     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
     * @dev Only one token per address is allowed
     */
    function mint(
        TokenId _tokenId,
        address _soulboundRecipient,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _soulboundRecipientScreeningData,
        uint256 _gridTileId
    ) external override(IIgnitionParticipantSoulbound) nonReentrant {
        _internalMint(
            msg.sender,
            _tokenId,
            _soulboundRecipient,
            _merkleProof,
            _identityProvider,
            _identityData,
            _soulboundRecipientScreeningData,
            _gridTileId
        );
    }

    /**
     * @notice Mint an IgnitionParticipant token to an address
     * @param _operator The address of the operator
     * @param _soulboundRecipient The address of the soulbound recipient
     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
     * @param _identityData Identity data - this is the data that the identity provider will verify
     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
     * @param _gridTileId The grid tile ID that the soulbound recipient is associated with
     * @dev Only one token per address is allowed
     */
    function mintFromSale(
        address _operator,
        address _soulboundRecipient,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _soulboundRecipientScreeningData,
        uint256 _gridTileId
    ) external override(IIgnitionParticipantSoulbound) nonReentrant {
        // Check that the caller is the token sale contract
        require(msg.sender == tokenSaleAddress, IgnitionParticipantSoulbound__CallerIsNotTokenSale());

        // Call mint, allowing the token sale contract to set the operator as the msg.sender of the sale
        // The sale is limited to GENESIS_SEQUENCER (token ID 0), so we can hardcode it here
        _internalMint(
            _operator,
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _soulboundRecipient,
            _merkleProof,
            _identityProvider,
            _identityData,
            _soulboundRecipientScreeningData,
            _gridTileId
        );
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Admin Functions                       */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /**
     * @notice Set the address of the token sale contract
     * @param _tokenSaleAddress The address of the token sale contract
     *
     * @dev onlyOwner
     */
    function setTokenSaleAddress(address _tokenSaleAddress) external override(IIgnitionParticipantSoulbound) onlyOwner {
        tokenSaleAddress = _tokenSaleAddress;
        emit TokenSaleAddressSet(_tokenSaleAddress);
    }

    /**
     * @notice Mint an IgnitionParticipant token to an address
     * @param _to The address to mint the token to
     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
     * @param _gridTileId The grid tile ID to mint
     *
     * @dev onlyOwner
     */
    function adminMint(address _to, TokenId _tokenId, uint256 _gridTileId)
        external
        override(IIgnitionParticipantSoulbound)
        onlyOwner
        nonReentrant
    {
        _internalAdminMint(_to, _tokenId, _gridTileId);
    }

    /**
     * @notice Batch mint IgnitionParticipant tokens to an array of addresses
     * @param _to The addresses to mint the tokens to
     * @param _tokenId The token IDs to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
     * @param _gridTileId The grid tile IDs to mint
     *
     * @dev onlyOwner
     */
    function adminBatchMint(address[] calldata _to, TokenId[] calldata _tokenId, uint256[] calldata _gridTileId)
        external
        override(IIgnitionParticipantSoulbound)
        onlyOwner
        nonReentrant
    {
        require(_to.length == _tokenId.length, IgnitionParticipantSoulbound__InvalidInputLength());
        require(_to.length == _gridTileId.length, IgnitionParticipantSoulbound__InvalidInputLength());

        for (uint256 i = 0; i < _to.length; i++) {
            _internalAdminMint(_to[i], _tokenId[i], _gridTileId[i]);
        }
    }

    /**
     * @notice Set the genesis sequencer merkle root
     * @param _genesisSequencerMerkleRoot The new merkle root
     *
     * @dev onlyOwner
     */
    function setGenesisSequencerMerkleRoot(bytes32 _genesisSequencerMerkleRoot)
        external
        override(IIgnitionParticipantSoulbound)
        onlyOwner
    {
        genesisSequencerMerkleRoot = _genesisSequencerMerkleRoot;
        emit GenesisSequencerMerkleRootUpdated(_genesisSequencerMerkleRoot);
    }

    /**
     * @notice Set the contributor merkle root
     * @param _contributorMerkleRoot The new merkle root
     *
     * @dev onlyOwner
     */
    function setContributorMerkleRoot(bytes32 _contributorMerkleRoot)
        external
        override(IIgnitionParticipantSoulbound)
        onlyOwner
    {
        contributorMerkleRoot = _contributorMerkleRoot;
        emit ContributorMerkleRootUpdated(_contributorMerkleRoot);
    }

    /**
     * @notice Set the whitelist provider
     * @param _provider The address of the whitelist provider
     * @param _active Whether the provider is active
     *
     * @dev onlyOwner
     */
    function setIdentityProvider(address _provider, bool _active)
        external
        override(IIgnitionParticipantSoulbound)
        onlyOwner
    {
        identityProviders[_provider] = _active;
        emit IdentityProviderSet(_provider, _active);
    }

    /**
     * @notice Set the screening provider
     * @param _provider The address of the screening provider
     *
     * @dev onlyOwner
     */
    function setAddressScreeningProvider(address _provider) external override(IIgnitionParticipantSoulbound) onlyOwner {
        addressScreeningProvider = _provider;
        emit AddressScreeningProviderSet(_provider);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       View Functions                      */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /**
     * @notice Check if an address has the merkle whitelist token
     * @param _addr Address to check
     * @return bool True if the address owns token ID 0
     */
    function hasGenesisSequencerToken(address _addr)
        external
        view
        override(IIgnitionParticipantSoulbound)
        returns (bool)
    {
        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0;
    }

    /**
     * @notice Check if an address has the contributor whitelist token
     * @param _addr Address to check
     * @return bool True if the address owns token ID 1
     */
    function hasContributorToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
        return balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0;
    }

    /**
     * @notice Check if an address has the general token
     * @param _addr Address to check
     * @return bool True if the address owns token ID 2
     */
    function hasGeneralToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
        return balanceOf(_addr, uint256(TokenId.GENERAL)) > 0;
    }

    /**
     * Check if an address has the genesis sequencer or contributor token
     * @param _addr Address to check
     * @return bool True if the address owns token ID 0 or 1
     */
    function hasGenesisSequencerTokenOrContributorToken(address _addr)
        external
        view
        override(IIgnitionParticipantSoulbound)
        returns (bool)
    {
        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0
            || balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0;
    }

    /**
     * @notice Check if an address has any token
     * @param _addr Address to check
     * @return bool True if the address owns any token ID (0,1, or 2)
     */
    function hasAnyToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0
            || balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0 || balanceOf(_addr, uint256(TokenId.GENERAL)) > 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*            ERC1155 Soulbound Override Functions            */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /**
     * @dev See {ERC1155-setApprovalForAll}. Overridden to prevent approvals.
     */
    function setApprovalForAll(address, bool) public pure override(IERC1155, ERC1155) {
        revert IgnitionParticipantSoulbound__TokenIsSoulbound();
    }

    /**
     * @dev See {ERC1155-_update}. Overridden to prevent transfers (soulbound).
     */
    function _update(address _from, address _to, uint256[] memory _ids, uint256[] memory _values)
        internal
        override(ERC1155)
    {
        // Allow minting (_from == address(0))
        // Prevent transfers (_from != address(0))
        if (_from != address(0)) {
            revert IgnitionParticipantSoulbound__TokenIsSoulbound();
        }

        super._update(_from, _to, _ids, _values);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Internal Functions                     */
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/

    /**
     * @notice Internal function to mint a token to an address
     * @param _identityAddress The address of the identity - checked to be in merkle tree's + identity provider checks
     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
     * @param _soulboundRecipient The address of the soulbound recipient
     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
     * @param _identityData Identity data - this is the data that the identity provider will verify
     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
     * @param _gridTileId The grid token ID to mint
     */
    function _internalMint(
        address _identityAddress,
        TokenId _tokenId,
        address _soulboundRecipient,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _soulboundRecipientScreeningData,
        uint256 _gridTileId
    ) internal {
        // Assert that the user has not minted yet
        require(!hasMinted[_identityAddress], IgnitionParticipantSoulbound__AlreadyMinted());
        hasMinted[_identityAddress] = true;

        require(_gridTileId != 0, IgnitionParticipantSoulbound__GridTileIdCannotBeZero());

        // Assert that the grid token ID has not already been assigned
        require(!isGridTileIdAssigned[_gridTileId], IgnitionParticipantSoulbound__GridTileAlreadyAssigned());
        isGridTileIdAssigned[_gridTileId] = true;

        gridTileId[_soulboundRecipient] = _gridTileId;

        // Verify identity provider is whitelisted
        require(identityProviders[_identityProvider], IgnitionParticipantSoulbound__InvalidAuth(_identityProvider));

        if (_tokenId == TokenId.GENESIS_SEQUENCER) {
            // Verify merkle proof for genesis sequencer whitelist
            require(genesisSequencerMerkleRoot != bytes32(0), IgnitionParticipantSoulbound__NoMerkleRootSet());

            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_identityAddress))));
            require(
                MerkleProof.verify(_merkleProof, genesisSequencerMerkleRoot, leaf),
                IgnitionParticipantSoulbound__MerkleProofInvalid()
            );
        } else if (_tokenId == TokenId.CONTRIBUTOR) {
            // Verify merkle proof for contributor whitelist
            require(contributorMerkleRoot != bytes32(0), IgnitionParticipantSoulbound__NoMerkleRootSet());

            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_identityAddress))));
            require(
                MerkleProof.verify(_merkleProof, contributorMerkleRoot, leaf),
                IgnitionParticipantSoulbound__MerkleProofInvalid()
            );
        }
        // Further steps required for all cases

        // Ext call
        // Perform sanctions check on the identity address
        require(
            IWhitelistProvider(_identityProvider).verify(_identityAddress, _identityData),
            IgnitionParticipantSoulbound__InvalidAuth(_identityProvider)
        );

        // Ext call
        // Perform sanctions check on the _soulboundRecipient address
        require(
            IWhitelistProvider(addressScreeningProvider).verify(_soulboundRecipient, _soulboundRecipientScreeningData),
            IgnitionParticipantSoulbound__InvalidAuth(addressScreeningProvider)
        );

        // Ext call - with possible reentrancy on acceptance check - nonReentrant added to prevent
        _mint(_soulboundRecipient, uint256(_tokenId), 1, "");

        emit IgnitionParticipantSoulboundMinted(_soulboundRecipient, _identityAddress, _tokenId, _gridTileId);
    }

    /**
     * @notice Internal function to mint a token to an address
     * @param _to The address to mint the token to
     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
     * @param _gridTileId The grid tile ID to mint
     */
    function _internalAdminMint(address _to, TokenId _tokenId, uint256 _gridTileId) internal {
        // The user must not have minted yet
        require(!hasMinted[_to], IgnitionParticipantSoulbound__AlreadyMinted());
        hasMinted[_to] = true;
        gridTileId[_to] = _gridTileId;

        require(!isGridTileIdAssigned[_gridTileId], IgnitionParticipantSoulbound__GridTileAlreadyAssigned());
        isGridTileIdAssigned[_gridTileId] = true;

        _mint(_to, uint256(_tokenId), 1, "");

        emit IgnitionParticipantSoulboundMinted(_to, msg.sender, _tokenId, _gridTileId);
    }
}
