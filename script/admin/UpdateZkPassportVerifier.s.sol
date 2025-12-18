import {Script} from "forge-std/Script.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";

pragma solidity ^0.8.27;

contract UpdateZkPassportVerifier is Script {
    address constant zkPassportProvider = 0xC9C7bCE71666943dbDBFe5b4c4D94ACedbff9B5c;

    address constant zkPassportVerifier = 0xBec82dec0747C9170D760D5aba9cc44929B17C05;

    function run() public {
        vm.startBroadcast();
        ZKPassportProvider(zkPassportProvider).setZKPassportVerifier(zkPassportVerifier);
        vm.stopBroadcast();
    }
}
