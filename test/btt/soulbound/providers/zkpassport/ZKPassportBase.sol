// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";

import {ZKPassportRootVerifier} from "@zkpassport/ZKPassportRootVerifier.sol";
import {ZKPassportSubVerifier} from "@zkpassport/ZKPassportSubVerifier.sol";
import {ZKPassportHelper} from "@zkpassport/ZKPassportHelper.sol";
import {ProofVerificationParams, ProofVerifier, ProofVerificationData, ServiceConfig} from "@zkpassport/Types.sol";
import {IRootRegistry} from "@zkpassport/IRootRegistry.sol";
import {HonkVerifier as OuterVerifier8} from "@zkpassport/ultra-honk-verifiers/OuterCount8.sol";
import {MockRootRegistry} from "test/mocks/MockRootRegistry.sol";
import {MockZKPassportVerifier} from "test/mocks/MockZKPassportVerifier.sol";

import {Test} from "forge-std/Test.sol";

abstract contract ZKPassportBase is Test {
    // ( When the proof is valid - any time after which the proof was made but before the validity period )
    // Set the timestamp to October 19, 2025 7:29:51Z
    uint256 public PROOF_GENERATION_TIMESTAMP = 1_764_268_926;
    // Set the timestamp to 2025-09-30T07:10:28Z
    uint256 public EXTRA_DISCLOSE_PROOF_GENERATION_TIMESTAMP = 1_764_269_272;

    ZKPassportProvider public zkPassportProvider;
    ZKPassportRootVerifier public zkPassportVerifier;
    ZKPassportSubVerifier public subVerifier;

    MockZKPassportVerifier public mockZKPassportVerifier;

    OuterVerifier8 public verifier;
    IRootRegistry public rootRegistry;

    ProofVerificationParams internal fakeProof;
    ProofVerificationParams internal realProof;

    // Path to the proof file - using files directly in project root
    // Fixtures copied from within the zk passport subrepo
    bytes32 constant VKEY_HASH = 0x2a999960f3377deedf24cb73d58e1fdb8bf7a6afb33278f52036713491c837fb;
    bytes32 constant VERIFIER_VERSION = bytes32(uint256(1));

    // From fixtures - see lib/circuits/src/solidity/test/SampleContract.t.sol
    string constant CORRECT_DOMAIN = "zkpassport.id";
    string constant CORRECT_SCOPE = "bigproof";

    address public zkPassportAdmin;
    address public zkPassportGuardian;

    // Using this base contract will make a zkpassport verifier and proof available for testing purposes
    function setUp() public virtual {
        zkPassportAdmin = makeAddr("admin");
        zkPassportGuardian = makeAddr("guardian");

        // Root registry for the zk passport verifier
        rootRegistry = new MockRootRegistry();

        // Deploy wrapper verifier
        zkPassportVerifier = new ZKPassportRootVerifier(zkPassportAdmin, zkPassportGuardian, rootRegistry);
        subVerifier = new ZKPassportSubVerifier(zkPassportAdmin, zkPassportVerifier);
        vm.prank(zkPassportAdmin);
        zkPassportVerifier.addSubVerifier(VERIFIER_VERSION, subVerifier);


        // Deploy actual circuit verifier
        verifier = new OuterVerifier8();
        ProofVerifier[] memory proofVerifiers = new ProofVerifier[](1);
        proofVerifiers[0] = ProofVerifier({vkeyHash: VKEY_HASH, verifier: address(verifier)});
        
        // Add proof verifiers to the sub verifier
        vm.prank(zkPassportAdmin);
        subVerifier.addProofVerifiers(proofVerifiers);

        ZKPassportHelper zkPassportHelper = new ZKPassportHelper(rootRegistry);

        // Deploy helper
        vm.prank(zkPassportAdmin);
        zkPassportVerifier.addHelper(VERIFIER_VERSION, address(zkPassportHelper));

        // ( When the proof was made )
        vm.warp(PROOF_GENERATION_TIMESTAMP);
        realProof = makeValidProof();
        fakeProof = makeFakeProof();

        // Mock verifier
        mockZKPassportVerifier = new MockZKPassportVerifier();

        zkPassportProvider =
            new ZKPassportProvider(address(this), address(zkPassportVerifier), CORRECT_DOMAIN, CORRECT_SCOPE);
    }

    function makeValidProofWithExtraDiscloseData() internal returns (ProofVerificationParams memory params) {
        bytes memory proof = loadBytesFromFile("valid_extra_disclose_proof.hex");
        bytes32[] memory publicInputs = loadBytes32FromFile("valid_extra_disclose_public_inputs.json");
        bytes memory committedInputs = loadBytesFromFile("valid_extra_disclose_committed_inputs.hex");

        vm.warp(EXTRA_DISCLOSE_PROOF_GENERATION_TIMESTAMP);
        params = ProofVerificationParams({
            version: VERIFIER_VERSION,
            proofVerificationData: ProofVerificationData({
                vkeyHash: VKEY_HASH, proof: proof, publicInputs: publicInputs
            }),
            committedInputs: committedInputs,
            serviceConfig: ServiceConfig({
                validityPeriodInSeconds: 7 days, domain: CORRECT_DOMAIN, scope: CORRECT_SCOPE, devMode: false
            })
        });
    }

    function makeValidProof() internal view returns (ProofVerificationParams memory params) {
        bytes memory proof = loadBytesFromFile("valid_proof.hex");
        bytes32[] memory publicInputs = loadBytes32FromFile("valid_public_inputs.json");
        bytes memory committedInputs = loadBytesFromFile("valid_committed_inputs.hex");

        params = ProofVerificationParams({
            version: VERIFIER_VERSION,
            proofVerificationData: ProofVerificationData({
                vkeyHash: VKEY_HASH, proof: proof, publicInputs: publicInputs
            }),
            committedInputs: committedInputs,
            serviceConfig: ServiceConfig({
                validityPeriodInSeconds: 7 days, domain: CORRECT_DOMAIN, scope: CORRECT_SCOPE, devMode: false
            })
        });
    }

    function makeFakeProof() internal pure returns (ProofVerificationParams memory params) {
        bytes memory proof = bytes(string(""));
        bytes32[] memory publicInputs = new bytes32[](0);
        bytes memory committedInputs = bytes(string(""));

        params = ProofVerificationParams({
            version: VERIFIER_VERSION,
            proofVerificationData: ProofVerificationData({
                vkeyHash: VKEY_HASH, proof: proof, publicInputs: publicInputs
            }),
            committedInputs: committedInputs,
            serviceConfig: ServiceConfig({
                validityPeriodInSeconds: 7 days, domain: "zkpassport.id", scope: "bigproof", devMode: true
            })
        });
    }

    /**
     * @dev Helper function to load proof data from a file
     */
    function loadBytesFromFile(string memory name) internal view returns (bytes memory) {
        // Try to read the file as a string
        string memory path = getPath(name);
        string memory proofHex = vm.readFile(path);

        // Check if content starts with 0x
        if (bytes(proofHex).length > 2 && bytes(proofHex)[0] == "0" && bytes(proofHex)[1] == "x") {
            proofHex = slice(proofHex, 2, bytes(proofHex).length - 2);
        }

        // Try to parse the bytes
        return vm.parseBytes(proofHex);
    }

    function getPath(string memory name) internal view returns (string memory path) {
        string memory root = vm.projectRoot();
        path = string.concat(root, "/test/btt/soulbound/providers/zkpassport/fixtures/", name);
    }

    /**
     * @dev Helper function to load public inputs from a file
     */
    function loadBytes32FromFile(string memory name) internal view returns (bytes32[] memory) {
        string memory path = getPath(name);

        string memory inputsJson = vm.readFile(path);
        // Parse the inputs from the file
        string[] memory inputs = vm.parseJsonStringArray(inputsJson, ".inputs");
        bytes32[] memory result = new bytes32[](inputs.length);

        for (uint256 i = 0; i < inputs.length; i++) {
            result[i] = vm.parseBytes32(inputs[i]);
        }

        return result;
    }

    /**
     * @dev Helper function to slice a string
     */
    function slice(string memory s, uint256 start, uint256 length) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        require(start + length <= b.length, "String slice out of bounds");

        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = b[start + i];
        }

        return string(result);
    }
}
