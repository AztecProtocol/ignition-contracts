// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

contract MockAuction {
    uint256 public clearingPrice = 1;

    function setClearingPrice(uint256 _clearingPrice) public {
        clearingPrice = _clearingPrice;
    }
}
