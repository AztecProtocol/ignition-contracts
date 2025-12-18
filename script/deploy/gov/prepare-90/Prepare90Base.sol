
// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

contract Prepare90Base is Test {
    function _loadJson() internal returns (string memory) {
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");
        return vm.readFile(inputPath);
    }
}
