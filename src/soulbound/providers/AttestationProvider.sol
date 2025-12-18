// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";
import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";
import {EIP712} from "@oz/utils/cryptography/EIP712.sol";
import {IWhitelistProvider} from "./IWhitelistProvider.sol";

struct Attestation {
    /// @notice The token id of the attestation is valid for
    uint256 tokenId;
    /// @notice The signature provider - from the attestation authority
    bytes signature;
}

interface IAttestationProvider is IWhitelistProvider {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event AttestationAuthoritySet(address indexed attestationAuthority);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error AttestationProvider__InvalidAttestation();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Admin Functions                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function setAttestationAuthority(address _attestationAuthority) external;
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      View Functions                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @title AttestationProvider
 * @author Aztec-Labs
 * @notice A Provider that verifies an attestation to some action verified offchain.
 */
contract AttestationProvider is IWhitelistProvider, IAttestationProvider, Ownable, EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant ATTESTATION_TYPEHASH =
        keccak256("Attestation(address provider,address attestationAuthority,address user,uint256 tokenId)");

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   State Variables                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The consumer of the provider - the soulbound contract
    address public consumer;

    /// @notice The attestation authority - the address that can sign attestations
    address public attestationAuthority;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Constructor                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Constructor
     * @param _consumer The consumer of the provider - the soulbound contract
     * @param _attestationAuthority The attestation authority - the address that can sign attestations
     */
    constructor(address _consumer, address _attestationAuthority)
        Ownable(msg.sender)
        EIP712("AttestationProvider", "1")
    {
        consumer = _consumer;
        attestationAuthority = _attestationAuthority;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Admin Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @param _attestationAuthority The attestation authority - the address that can sign attestations
     * @dev onlyOwner
     */
    function setAttestationAuthority(address _attestationAuthority) external override(IAttestationProvider) onlyOwner {
        attestationAuthority = _attestationAuthority;
        emit AttestationAuthoritySet(_attestationAuthority);
    }

    /**
     * @param _consumer The consumer of the provider - the soulbound contract
     * @dev onlyOwner
     */
    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
        consumer = _consumer;
        emit ConsumerSet(_consumer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Verify Logic                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Verifies an attestation
     * @param _user The user's address
     * @param _auth The authentication data
     * @return True if the attestation is valid
     */
    function verify(address _user, bytes memory _auth) external view override(IWhitelistProvider) returns (bool) {
        // The call must come from the expected consumer, such that _user field cannot be spoofed
        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());

        // Decode the attestation from _auth
        Attestation memory attestation = abi.decode(_auth, (Attestation));

        // Validate signature length (should be 65 bytes: r + s + v)
        require(attestation.signature.length == 65, AttestationProvider__InvalidAttestation());

        // Create the structured data hash
        bytes32 structHash = keccak256(
            abi.encode(ATTESTATION_TYPEHASH, address(this), attestationAuthority, _user, attestation.tokenId)
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        // Recover the signer and verify it's the attestation authority
        address signer = digest.recover(attestation.signature);
        require(signer == attestationAuthority, AttestationProvider__InvalidAttestation());

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     View Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function DOMAIN_SEPARATOR() external view override(IAttestationProvider) returns (bytes32) {
        return _domainSeparatorV4();
    }
}
