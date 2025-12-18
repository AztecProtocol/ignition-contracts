// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Script} from "forge-std/Script.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";

contract UpdateScreeningProvider is Script {
    address public constant PREDICATE_SANCTIONS_PROVIDER_SALE = 0xE61EF35aDF12f6a435Ca79a187358037255AEB58;
    address public constant SALE_ADDRESS = 0xf910B0A64399704b28957484383E81D7218ee90D;

    function run() public {
        vm.startBroadcast();
        IGenesisSequencerSale(SALE_ADDRESS).setAddressScreeningProvider(PREDICATE_SANCTIONS_PROVIDER_SALE);
        vm.stopBroadcast();
    }
}
