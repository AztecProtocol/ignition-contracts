// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";

contract MockRegistry is IRegistry {
    error InvalidRollupVersion(uint256 version);

    address public canonicalRollup;
    uint256 public currentVersion;
    mapping(uint256 => address) public rollups;
    address public governance;

    constructor(address _governance) {
        governance = _governance;
    }

    function getCanonicalRollup() external view returns (address) {
        return rollups[currentVersion];
    }

    function addRollup(uint256 _version, address _rollup) external {
        rollups[_version] = _rollup;
        currentVersion = _version;
    }

    function getRollup(uint256 _version) external view returns (address) {
        require(rollups[_version] != address(0), InvalidRollupVersion(_version));

        return rollups[_version];
    }

    function getGovernance() external view returns (address) {
        return governance;
    }
}
