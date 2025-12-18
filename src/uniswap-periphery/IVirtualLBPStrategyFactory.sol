pragma solidity ^0.8.0;

import {IDistributionStrategy} from "@launcher/interfaces/IDistributionStrategy.sol";

interface IVirtualLBPStrategyFactory is IDistributionStrategy {
    function getVirtualLBPAddress(
        address token,
        uint256 totalSupply,
        bytes calldata configData,
        bytes32 salt,
        address sender
    ) external view returns (address);
}