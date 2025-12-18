// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IERC1155} from "@oz/token/ERC1155/IERC1155.sol";

interface IIgnitionParticipantSoulbound is IERC1155 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Structs                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    enum TokenId {
        GENESIS_SEQUENCER,
        CONTRIBUTOR,
        GENERAL
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event IgnitionParticipantSoulboundMinted(
        address indexed _beneficiary, address indexed _operator, TokenId indexed _tokenId, uint256 _gridTileId
    );
    event GenesisSequencerMerkleRootUpdated(bytes32 newRoot);
    event ContributorMerkleRootUpdated(bytes32 newRoot);
    event IdentityProviderSet(address provider, bool active);
    event AddressScreeningProviderSet(address provider);
    event TokenSaleAddressSet(address tokenSaleAddress);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error IgnitionParticipantSoulbound__CallerIsNotTokenSale();
    error IgnitionParticipantSoulbound__TokenIsSoulbound();
    error IgnitionParticipantSoulbound__AlreadyMinted();
    error IgnitionParticipantSoulbound__GridTileIdCannotBeZero();
    error IgnitionParticipantSoulbound__InvalidAuth(address _authProvider);
    error IgnitionParticipantSoulbound__MerkleProofInvalid();
    error IgnitionParticipantSoulbound__NoMerkleRootSet();
    error IgnitionParticipantSoulbound__InvalidInputLength();
    error IgnitionParticipantSoulbound__GridTileAlreadyAssigned();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Functions                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function mint(
        TokenId _tokenId,
        address _beneficiary,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _beneficiaryScreeningData,
        uint256 _gridTileId
    ) external;

    function mintFromSale(
        address _operator,
        address _beneficiary,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _beneficiaryScreeningData,
        uint256 _gridTileId
    ) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Admin Functions                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function adminMint(address _to, TokenId _tokenId, uint256 _gridTileId) external;
    function adminBatchMint(address[] calldata _to, TokenId[] calldata _tokenId, uint256[] calldata _gridTileId)
        external;
    function setGenesisSequencerMerkleRoot(bytes32 _genesisSequencerMerkleRoot) external;
    function setContributorMerkleRoot(bytes32 _contributorMerkleRoot) external;
    function setIdentityProvider(address _provider, bool _active) external;
    function setAddressScreeningProvider(address _provider) external;
    function setTokenSaleAddress(address _tokenSaleAddress) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      View Functions                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function hasGenesisSequencerToken(address _addr) external view returns (bool);
    function hasContributorToken(address _addr) external view returns (bool);
    function hasGenesisSequencerTokenOrContributorToken(address _addr) external view returns (bool);
    function hasGeneralToken(address _addr) external view returns (bool);
    function hasAnyToken(address _addr) external view returns (bool);
    function genesisSequencerMerkleRoot() external view returns (bytes32);
    function contributorMerkleRoot() external view returns (bytes32);
    function identityProviders(address _provider) external view returns (bool);
    function gridTileId(address _addr) external view returns (uint256);
}
