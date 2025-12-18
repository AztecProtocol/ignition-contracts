// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

contract Staking {
    IERC20 public immutable TOKEN;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewards;

    constructor(IERC20 _token) {
        TOKEN = _token;
    }

    function stake(address _to, uint256 _amount) external {
        TOKEN.transferFrom(msg.sender, address(this), _amount);
        staked[_to] += _amount;
    }

    function unstake(address _recipient, uint256 _amount) external {
        staked[msg.sender] -= _amount;
        TOKEN.transfer(_recipient, _amount);
    }

    function slash(address _offender, uint256 _amount) external {
        staked[_offender] -= _amount;
    }

    function reward(address _to, uint256 _amount) external {
        rewards[_to] += _amount;
    }

    function claim(address _to) external {
        uint256 r = rewards[msg.sender];
        rewards[msg.sender] = 0;
        TOKEN.transfer(_to, r);
    }

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}
