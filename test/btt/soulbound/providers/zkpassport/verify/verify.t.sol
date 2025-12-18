// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {ZKPassportBase} from "../ZKPassportBase.sol";
import {ProofVerificationParams, ProofVerifier} from "@zkpassport/Types.sol";

import {IZKPassportProviderLegacy} from "src/soulbound/providers/ZKPassportProviderLegacy.sol";
import {IWhitelistProvider, IZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";
import {IVerifier} from "@zkpassport/ultra-honk-verifiers/OuterCount7.sol";

contract AlwaysReturnFalseVerifier is IVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool) {
        return false;
    }
}

contract ZKPassportVerify is ZKPassportBase {
    address public constant BOUND_ADDRESS = 0x04Fb06E8BF44eC60b6A99D2F98551172b2F2dED8;
    ProofVerificationParams public proof;

    function setUp() public override {
        super.setUp();
    }

    modifier givenAValidZkpassportProof() {
        proof = realProof;
        _;
    }

    modifier givenAnInvalidZkpassportProof() {
        proof = fakeProof;
        _;
    }

    modifier givenAValidZKPassportProofWithExtraDiscloseData() {
        proof = makeValidProofWithExtraDiscloseData();
        _;
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenCallerIsNotTheConsumer(address _user) external {
        // it reverts with {InvalidConsumer}
        vm.assume(_user != address(zkPassportProvider.consumer()));
        vm.prank(_user);
        vm.expectRevert(abi.encodeWithSelector(IWhitelistProvider.WhitelistProvider__InvalidConsumer.selector));
        zkPassportProvider.verify(_user, abi.encode(proof));
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenDomainDoesntMatch(string calldata _domain) external givenAValidZkpassportProof {
        // it reverts with {InvalidProof}
        vm.assume(keccak256(bytes(_domain)) != keccak256(bytes(zkPassportProvider.domain())));
        proof.serviceConfig.domain = _domain;
        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidDomain.selector));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenScopeDoesntMatch(string calldata _scope) external givenAValidZkpassportProof {
        // it reverts with {InvalidProof}
        vm.assume(keccak256(bytes(_scope)) != keccak256(bytes(zkPassportProvider.scope())));
        proof.serviceConfig.scope = _scope;
        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidScope.selector));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    function test_WhenDevModeIsTrue() external givenAnInvalidZkpassportProof {
        // it reverts with {InvalidProof}
        proof.serviceConfig.devMode = true;
        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidProof.selector));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    function test_WhenVerifierChecksTheProofAndReturnsFalse() external givenAValidZkpassportProof {
        AlwaysReturnFalseVerifier falseVerifier = new AlwaysReturnFalseVerifier();

        // Replace the verifier
        ProofVerifier[] memory proofVerifiers = new ProofVerifier[](1);
        proofVerifiers[0] = ProofVerifier({vkeyHash: VKEY_HASH, verifier: address(falseVerifier)});
        vm.prank(zkPassportAdmin);
        subVerifier.addProofVerifiers(proofVerifiers);

        // it reverts with {InvalidProof}
        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidProof.selector));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    function test_GivenAValidZKPassportProofWithExtraDiscloseData()
        external
        givenAValidZKPassportProofWithExtraDiscloseData
    {
        vm.expectRevert(
            abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__ExtraDiscloseDataNonZero.selector)
        );
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheChainIdDoesntMatch(uint64 _chainId) external givenAValidZkpassportProof {
        // it reverts with {InvalidProof}
        vm.assume(_chainId != block.chainid);
        vm.chainId(_chainId);
        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidBoundChainId.selector));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheBoundAddressIsInvalid(address _addr) external givenAValidZkpassportProof {
        // It reverts with {InvalidProof}
        vm.assume(_addr != BOUND_ADDRESS);

        vm.prank(address(zkPassportProvider.consumer()));
        vm.expectRevert(abi.encodeWithSelector(IZKPassportProviderLegacy.ZKPassportProvider__InvalidBoundAddress.selector));
        zkPassportProvider.verify(_addr, abi.encode(proof));
    }

    function test_ValidProof() external givenAValidZkpassportProof {
        // it returns true
        // Must come from the consumer
        vm.prank(address(zkPassportProvider.consumer()));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }

    function test_WhenTheProofIsAlreadyUsed() external givenAValidZkpassportProof {
        // it reverts with {SybilDetected}
        vm.startPrank(address(zkPassportProvider.consumer()));
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
        vm.expectRevert(
            abi.encodeWithSelector(
                IZKPassportProviderLegacy.ZKPassportProvider__SybilDetected.selector,
                proof.proofVerificationData.publicInputs[proof.proofVerificationData.publicInputs.length - 1]
            )
        );
        zkPassportProvider.verify(BOUND_ADDRESS, abi.encode(proof));
    }
}
