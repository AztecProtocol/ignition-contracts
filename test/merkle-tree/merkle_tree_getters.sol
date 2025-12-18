// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";

contract TestMerkleTreeGetters is Test {
    enum MerkleTreeType {
        GenesisSequencer,
        Contributor
    }

    function getRoot(MerkleTreeType _type) internal returns (bytes32) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/test-utils/utils/get-root.js";
        inputs[2] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);

        return bytes32(result);
    }

    function getAddress(uint256 index, MerkleTreeType _type) internal returns (address) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/test-utils/utils/get-address.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);

        return address(uint160(uint256(bytes32(result))));
    }

    function getMerkleProof(uint256 index, MerkleTreeType _type) internal returns (bytes32[] memory) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/test-utils/utils/get-proof.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proof = abi.decode(result, (bytes32[]));

        return proof;
    }

    function getAddressAndProof(uint256 index, MerkleTreeType _type)
        internal
        returns (address addr, bytes32[] memory proof)
    {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/test-utils/utils/get-address-and-proof.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);
        (addr, proof) = abi.decode(result, (address, bytes32[]));
    }

    function makeMerkleTreeAndGetProof(address _address) internal returns (bytes32 root) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/test-utils/utils/make-merkle-tree-and-proof.js";
        inputs[2] = vm.toString(address(_address));

        bytes memory result = vm.ffi(inputs);
        root = abi.decode(result, (bytes32));
    }
}

contract MerkleTreeGetters is Test {
    enum MerkleTreeType {
        GenesisSequencer,
        Contributor
    }

    function getRoot(MerkleTreeType _type) internal returns (bytes32) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/utils/get-root.js";
        inputs[2] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);

        return bytes32(result);
    }

    function getAddress(uint256 index, MerkleTreeType _type) internal returns (address) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/utils/get-address.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);

        return address(uint160(uint256(bytes32(result))));
    }

    function getMerkleProof(uint256 index, MerkleTreeType _type) internal returns (bytes32[] memory) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/utils/get-proof.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proof = abi.decode(result, (bytes32[]));

        return proof;
    }

    function getAddressAndProof(uint256 index, MerkleTreeType _type)
        internal
        returns (address addr, bytes32[] memory proof)
    {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/utils/get-address-and-proof.js";
        inputs[2] = vm.toString(index);
        inputs[3] = vm.toString(uint256(_type));

        bytes memory result = vm.ffi(inputs);
        (addr, proof) = abi.decode(result, (address, bytes32[]));
    }

    function makeMerkleTreeAndGetProof(address _address) internal returns (bytes32 root) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "merkle-tree/utils/make-merkle-tree-and-proof.js";
        inputs[2] = vm.toString(address(_address));

        bytes memory result = vm.ffi(inputs);
        root = abi.decode(result, (bytes32));
    }
}
