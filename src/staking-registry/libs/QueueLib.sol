// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

struct Queue {
    mapping(uint256 index => IStakingRegistry.KeyStore keyStore) keyStores;
    uint128 first;
    uint128 last;
}

library QueueLib {
    error QueueIsEmpty();
    error QueueIndexOutOfBounds();

    function init(Queue storage _self) internal {
        _self.first = 1;
        _self.last = 1;
    }

    function enqueue(Queue storage _self, IStakingRegistry.KeyStore memory _keyStore) internal returns (uint128) {
        uint128 queueLocation = _self.last;

        _self.keyStores[queueLocation] = _keyStore;
        _self.last = queueLocation + 1;

        return queueLocation;
    }

    function dequeue(Queue storage _self) internal returns (IStakingRegistry.KeyStore memory) {
        require(_self.last > _self.first, QueueIsEmpty());

        IStakingRegistry.KeyStore memory keyStore = _self.keyStores[_self.first];
        _self.first += 1;

        return keyStore;
    }

    function getValueAtIndex(Queue storage _self, uint128 _index)
        internal
        view
        returns (IStakingRegistry.KeyStore memory)
    {
        require(_index >= _self.first && _index < _self.last, QueueIndexOutOfBounds());
        return _self.keyStores[_index];
    }

    function length(Queue storage _self) internal view returns (uint128) {
        return _self.last - _self.first;
    }

    function getFirstIndex(Queue storage _self) internal view returns (uint128) {
        return _self.first;
    }

    function getLastIndex(Queue storage _self) internal view returns (uint128) {
        return _self.last;
    }
}
