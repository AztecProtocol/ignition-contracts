pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";

import "forge-std/console.sol";

contract AddNullifiers is Script {

    // not deployed yet
    // address constant ZKPASSPORT_PROVIDER = ;

    function howManyNullifiers() public returns (uint256) {
        string[] memory commands = new string[](1);
        commands[0] = "./script/admin/zkpassport/how_many_nullifiers.sh";
        bytes memory output = vm.ffi(commands);
        bytes memory parsedOutput = vm.parseBytes(string(output));
        return abi.decode(parsedOutput, (uint256));
    }

    function getNullifiersFromFile(uint256 startIndex, uint256 chunkSize) public returns (bytes32[] memory) {
        string[] memory commands = new string[](3);
        commands[0] = "./script/admin/zkpassport/get_nullifiers.sh";
        commands[1] = vm.toString(startIndex);
        commands[2] = vm.toString(chunkSize);

        // FFI returns UTF-8 text, so we need to parse the hex string into actual bytes
        bytes memory output = vm.ffi(commands);
        // bytes memory parsedOutput = vm.parseBytes(string(output));
        return abi.decode(output, (bytes32[]));
    }

    function run() public {
        address ZKPASSPORT_PROVIDER = address(0xe4f80f2597FA53bF5adB013aE1E1eb1DE4fEF479);
        // uint256 nullifiersCount = howManyNullifiers();
        // there are 1893

        // Split into chunks of 500
        bytes32[] memory chunk0 = getNullifiersFromFile(0, 500);
        bytes32[] memory chunk1 = getNullifiersFromFile(500, 500);
        bytes32[] memory chunk2 = getNullifiersFromFile(1000, 500);
        bytes32[] memory chunk3 = getNullifiersFromFile(1500, 1893 - 1500);

        // Add nullifiers to ZKPassportProvider
        vm.startBroadcast();
        ZKPassportProvider(ZKPASSPORT_PROVIDER).portNullifiers(chunk0);
        ZKPassportProvider(ZKPASSPORT_PROVIDER).portNullifiers(chunk1);
        ZKPassportProvider(ZKPASSPORT_PROVIDER).portNullifiers(chunk2);
        ZKPassportProvider(ZKPASSPORT_PROVIDER).portNullifiers(chunk3);
        vm.stopBroadcast();
    }
}