// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface IERC20Mintable {
    function mint(address _to, uint256 _amount) external;
}
