// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;
import {Ownable} from "@oz/access/Ownable.sol";
import {IWhitelistProvider} from "../../src/soulbound/providers/IWhitelistProvider.sol";

contract MockPredicateProvider is Ownable, IWhitelistProvider {
    address public consumer;

    string internal policy;
    address internal manager;

    constructor(address __owner, address _manager, string memory _policy) Ownable(__owner) {
        manager = _manager;
        policy = _policy;
    }

    function verify(address, bytes calldata) external pure returns(bool){
        return true;
    }

    function setConsumer(address _consumer) external onlyOwner {
        consumer = _consumer;
    }

    function getPolicy() external view returns(string memory) {
        return policy;
    }

    function getPredicateManager() external view returns(address){
        return manager;
    }
}

