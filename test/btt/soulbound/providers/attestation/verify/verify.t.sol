// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {AttestationBase} from "../AttestationBase.sol";
import {IAttestationProvider, Attestation} from "src/soulbound/providers/AttestationProvider.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";

contract AttestationVerifyTest is AttestationBase {
    uint256 internal authorityPrivateKey;
    address internal authority;
    address internal user;
    address internal consumer;

    bytes32 private constant ATTESTATION_TYPEHASH =
        keccak256("Attestation(address provider,address attestationAuthority,address user,uint256 tokenId)");

    function setUp() public override {
        super.setUp();

        authorityPrivateKey = 0x1234;
        authority = vm.addr(authorityPrivateKey);
        user = makeAddr("user");
        consumer = makeAddr("consumer");

        // Set up the attestation provider
        attestationProvider.setAttestationAuthority(authority);
        attestationProvider.setConsumer(consumer);
    }

    function _signAttestation(address _user, uint256 _tokenId) internal view returns (bytes memory) {
        bytes32 domainSeparator = attestationProvider.DOMAIN_SEPARATOR();
        bytes32 structHash =
            keccak256(abi.encode(ATTESTATION_TYPEHASH, address(attestationProvider), authority, _user, _tokenId));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorityPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _boundTokenId(uint8 _tokenId) internal pure returns (uint256) {
        return uint256(bound(_tokenId, 0, uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL) + 1));
    }

    modifier whenCallerIsNotTheConsumer() {
        vm.startPrank(makeAddr("not-consumer"));
        _;
    }

    modifier whenCallerIsTheConsumer() {
        vm.startPrank(consumer);
        _;
    }

    function test_WhenCallerIsNotTheConsumer(uint8 _tokenId) external whenCallerIsNotTheConsumer {
        uint256 tokenId = _boundTokenId(_tokenId);

        bytes memory signature = _signAttestation(user, tokenId);
        Attestation memory attestation = Attestation(tokenId, signature);
        bytes memory authData = abi.encode(attestation);

        // it reverts with InvalidConsumer
        vm.expectRevert(IWhitelistProvider.WhitelistProvider__InvalidConsumer.selector);
        attestationProvider.verify(user, authData);
    }

    function test_WhenSignatureHasWrongLength(uint8 _tokenId) external whenCallerIsTheConsumer {
        // it reverts with {InvalidAttestation}

        uint256 tokenId = _boundTokenId(_tokenId);

        bytes memory wrongSignature = "0x1234"; // Wrong length
        Attestation memory attestation = Attestation(tokenId, wrongSignature);
        bytes memory authData = abi.encode(attestation);

        vm.expectRevert(IAttestationProvider.AttestationProvider__InvalidAttestation.selector);
        attestationProvider.verify(user, authData);
    }

    function test_WhenSignerIsNotAttestationAuthority(uint8 _tokenId, uint256 _wrongPrivateKey)
        external
        whenCallerIsTheConsumer
    {
        // it reverts with {InvalidAttestation}

        uint256 tokenId = _boundTokenId(_tokenId);

        // not the signer and must be less than the secp curve order
        vm.assume(
            _wrongPrivateKey != authorityPrivateKey
                && _wrongPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
                && _wrongPrivateKey > 0
        );

        // Sign with a different private key
        bytes32 domainSeparator = attestationProvider.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(ATTESTATION_TYPEHASH, user, tokenId));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        Attestation memory attestation = Attestation(tokenId, signature);
        bytes memory authData = abi.encode(attestation);

        vm.expectRevert(IAttestationProvider.AttestationProvider__InvalidAttestation.selector);
        attestationProvider.verify(user, authData);
    }

    function test_WhenSignatureIsForDifferentUser(uint8 _tokenId, address _differentUser)
        external
        whenCallerIsTheConsumer
    {
        // it reverts with {InvalidAttestation}

        uint256 tokenId = _boundTokenId(_tokenId);
        vm.assume(_differentUser != authority);

        address differentUser = makeAddr("different-user");

        // Sign attestation for different user
        bytes memory signature = _signAttestation(differentUser, tokenId);
        Attestation memory attestation = Attestation(tokenId, signature);
        bytes memory authData = abi.encode(attestation);

        vm.expectRevert(IAttestationProvider.AttestationProvider__InvalidAttestation.selector);
        attestationProvider.verify(user, authData);
    }

    function test_WhenSignatureIsValid(uint8 _tokenId) external whenCallerIsTheConsumer {
        // it returns true

        uint256 tokenId = _boundTokenId(_tokenId);

        bytes memory signature = _signAttestation(user, tokenId);
        Attestation memory attestation = Attestation(tokenId, signature);
        bytes memory authData = abi.encode(attestation);

        bool result = attestationProvider.verify(user, authData);
        assertTrue(result);
    }
}
