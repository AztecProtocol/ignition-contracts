pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";

contract DeployNewZKPassport is Script {
    function run() public returns (address) {
        address soulbound = address(0xBf3CF56c587F5e833337200536A52E171EF29A09);
        address zkPassportVerifier = address(0x1D000001000EFD9a6371f4d90bB8920D5431c0D8);
        string memory domain = "sale.aztec.network";
        string memory scope = "sanctions";

        vm.startBroadcast();
        ZKPassportProvider zkPassportProvider = new ZKPassportProvider(
            soulbound,
            zkPassportVerifier,
            domain,
            scope
        );

        vm.stopBroadcast();
        return address(zkPassportProvider);
    }
}