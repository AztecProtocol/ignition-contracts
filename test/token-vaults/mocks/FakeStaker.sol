// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {Staking} from "./Staking.sol";
import {BaseStaker} from "src/token-vaults/staker/BaseStaker.sol";

contract FakeStaker is BaseStaker {
    Staking public immutable STAKING;
    IERC20 public immutable TOKEN;

    constructor(Staking _staking) {
        STAKING = _staking;
        TOKEN = _staking.TOKEN();
    }

    function stake(uint256 _amount) external onlyOperator {
        TOKEN.transferFrom(address(atp), address(this), _amount);
        TOKEN.approve(address(STAKING), _amount);
        STAKING.stake(address(this), _amount);
    }

    function unstake(uint256 _amount) external onlyOperator {
        STAKING.unstake(address(atp), _amount);
    }

    function claim() external onlyOperator {
        STAKING.claim(address(atp));
    }

    function test() external virtual {}
}
