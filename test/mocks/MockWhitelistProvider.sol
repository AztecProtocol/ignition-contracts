// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IWhitelistProvider} from "../../src/soulbound/providers/IWhitelistProvider.sol";

contract MockTrueWhitelistProvider is IWhitelistProvider {
    function verify(address, bytes calldata) external pure returns (bool) {
        return true;
    }

    function setConsumer(address) external pure {}
}

contract MockFalseWhitelistProvider is IWhitelistProvider {
    function verify(address, bytes calldata) external pure returns (bool) {
        return false;
    }

    function setConsumer(address) external pure {}
}
