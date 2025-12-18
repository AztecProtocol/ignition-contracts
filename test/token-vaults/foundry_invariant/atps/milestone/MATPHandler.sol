// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {Staking} from "test/token-vaults/mocks/Staking.sol";
import {Aztec, IMATP} from "test/token-vaults/Importer.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

/**
 * @notice  A small Handler contract around the LATP to help when testing invariants
 * @dev     Emit events when executing functions to make it simpler to follow flows if needed
 */
contract Handler is Test {
    IMATP public atp;
    Staking public staking;
    FakeStaker public staker;
    IERC20 public token;

    uint256 public upperTime;
    uint256 public reward;

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }

    function prepare(IMATP _atp, uint256 _upperTime) public {
        require(address(atp) == address(0), "atp is already set");
        atp = _atp;
        staker = FakeStaker(address(_atp.getStaker()));
        token = _atp.getToken();
        staking = staker.STAKING();
        upperTime = _upperTime;
    }

    // The invariants are not happy around time, so we need to help it a bit.
    function advanceTime(uint256 _time) public {
        uint256 time = bound(_time, 1, upperTime);
        vm.warp(block.timestamp + time);
        emit log_named_uint("advanceTime to", block.timestamp);
    }

    function giveReward(uint256 _amount) public {
        uint256 amount = bound(_amount, 1, 10e18);
        address owner = Aztec(address(token)).owner();
        vm.prank(owner);
        Aztec(address(token)).mint(address(atp), amount);
        reward += amount;
        emit log_named_decimal_uint("giveReward", amount, 18);
    }

    function claimRewards() public {
        address operator = staker.getOperator();
        vm.prank(operator);
        staker.claim();
    }

    function claim() public returns (uint256) {
        address beneficiary = atp.getBeneficiary();
        vm.prank(beneficiary);
        uint256 c = atp.claim();
        emit log_named_decimal_uint("claim", c, 18);
        return c;
    }

    function approveStaker(uint256 _amount) public {
        emit log_named_decimal_uint("approveStaker", _amount, 18);
        address beneficiary = atp.getBeneficiary();
        vm.prank(beneficiary);
        atp.approveStaker(_amount);
    }

    function stake(uint256 _amount) public {
        // Staking up to the balance might not be possible if revokable, but it is neat way to test the invariant
        // to see if it can find a case where we can actually move the funds out.
        uint256 balance = token.balanceOf(address(atp));
        uint256 amount = bound(_amount, 0, balance);
        emit log_named_decimal_uint("stake", amount, 18);
        address operator = staker.getOperator();
        vm.prank(operator);
        staker.stake(amount);
    }

    function unstake(uint256 _amount) public {
        uint256 balance = staking.staked(address(staker));
        uint256 amount = bound(_amount, 0, balance);
        emit log_named_decimal_uint("unstake", amount, 18);
        address operator = staker.getOperator();
        vm.prank(operator);
        staker.unstake(amount);
    }
}
