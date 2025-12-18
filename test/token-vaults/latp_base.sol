// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {Staking} from "test/token-vaults/mocks/Staking.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

import {Aztec, ATPFactory, IRegistry, ILATP, LockParams, Lock, LockLib, StakerVersion} from "test/token-vaults/Importer.sol";

abstract contract LATPTestBase is Test {
    using LockLib for Lock;

    Aztec internal aztec;
    IERC20 internal token;
    IRegistry internal registry;
    ATPFactory internal atpFactory;

    address internal revokeBeneficiary = address(bytes20("revoke beneficiary"));

    // @note    Default values for the registry
    //          Can be overwritten in the setUp functions
    uint256 internal unlockCliffDuration = 250;
    uint256 internal unlockLockDuration = 1000;

    uint256 internal unlockStartTime = 1;

    Staking private staking;
    StakerVersion internal fakeStakerVersion;

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }

    function setUp() public virtual {
        aztec = new Aztec(address(this));
        token = IERC20(address(aztec));

        vm.label(address(token), "Token");

        atpFactory = new ATPFactory({
            __owner: address(this),
            _token: token,
            _unlockCliffDuration: unlockCliffDuration,
            _unlockLockDuration: unlockLockDuration
        });
        atpFactory.setMinter(address(this), true);

        // The LATP factory is funded with type(uint128).max tokens
        aztec.mint(address(atpFactory), type(uint128).max);

        registry = atpFactory.getRegistry();
        registry.setRevoker(address(bytes20("revoker")));

        staking = new Staking(token);
        FakeStaker fakeStakerImplementation = new FakeStaker(staking);

        fakeStakerVersion = registry.getNextStakerVersion();
        registry.registerStakerImplementation(address(fakeStakerImplementation));

        // We set the unlock to start now.
        // @note reading the `unlockStartTime` from storage, such that we can overwrite it when setting up tests.
        registry.setUnlockStartTime(unlockStartTime);
    }

    function help_upgrade(ILATP _atp, address _operator) internal {
        address beneficiary = _atp.getBeneficiary();

        vm.prank(beneficiary);
        _atp.upgradeStaker(fakeStakerVersion);

        vm.prank(beneficiary);
        _atp.updateStakerOperator(_operator);
    }

    function help_approve(ILATP _atp, uint256 _amount) internal {
        address beneficiary = _atp.getBeneficiary();
        vm.prank(beneficiary);
        _atp.approveStaker(_amount);
    }

    function help_stake(ILATP _atp, uint256 _amount) internal {
        FakeStaker fakeStaker = FakeStaker(address(_atp.getStaker()));
        address operator = fakeStaker.getOperator();
        vm.prank(operator);
        fakeStaker.stake(_amount);
    }

    function help_unstake(ILATP _atp, uint256 _amount) internal {
        FakeStaker fakeStaker = FakeStaker(address(_atp.getStaker()));
        address operator = fakeStaker.getOperator();
        uint256 balance = token.balanceOf(address(_atp));
        vm.prank(operator);
        fakeStaker.unstake(_amount);
        assertEq(token.balanceOf(address(_atp)), balance + _amount, "balance mismatch");
    }

    function help_slash(ILATP _atp, uint256 _amount) internal {
        address staker = address(_atp.getStaker());
        staking.slash(staker, _amount);
    }

    function help_getStaked(ILATP _atp) internal view returns (uint256) {
        address staker = address(_atp.getStaker());
        return staking.staked(staker);
    }

    function help_getRewards(ILATP _atp) internal view returns (uint256) {
        address staker = address(_atp.getStaker());
        return staking.rewards(staker);
    }

    function help_mintReward(ILATP _atp, uint256 _amount) internal {
        address staker = address(_atp.getStaker());
        aztec.mint(address(staking), _amount);
        staking.reward(staker, _amount);
    }

    function help_claimRewards(ILATP _atp) internal {
        FakeStaker fakeStaker = FakeStaker(address(_atp.getStaker()));
        address operator = fakeStaker.getOperator();
        uint256 rewards = help_getRewards(_atp);
        uint256 balance = token.balanceOf(address(_atp));
        vm.prank(operator);
        fakeStaker.claim();
        assertEq(token.balanceOf(address(_atp)), balance + rewards, "balance mismatch");
    }

    function help_computeUnlocked(ILATP _atp, uint256 _time) internal view returns (uint256) {
        return _atp.getGlobalLock().unlockedAt(_time);
    }

    function help_computeAccumulated(ILATP _atp, uint256 _time) internal view returns (uint256) {
        return _atp.getAccumulationLock().unlockedAt(_time);
    }

    function help_computeUsed(ILATP _atp) internal view returns (uint256) {
        uint256 allocationLeft = _atp.getAllocation() - _atp.getClaimed();
        uint256 balance = _atp.getToken().balanceOf(address(_atp));
        return (balance >= allocationLeft) ? 0 : allocationLeft - balance;
    }

    function help_log(ILATP _atp) internal {
        uint256 balance = token.balanceOf(address(_atp));
        uint256 claimed = _atp.getClaimed();
        uint256 used = help_computeUsed(_atp);
        uint256 unlocked = help_computeUnlocked(_atp, block.timestamp);

        bool isRevokable = _atp.getIsRevokable();
        uint256 allocated = isRevokable ? help_computeAccumulated(_atp, block.timestamp) : 0;

        emit log_named_decimal_uint("balance  ", balance, 18);
        emit log_named_decimal_uint("used     ", used, 18);
        emit log_named_decimal_uint("claimed  ", claimed, 18);
        emit log_named_decimal_uint("unlocked ", unlocked, 18);
        if (isRevokable) {
            emit log_named_decimal_uint("allocated", allocated, 18);
        }
    }

    function isLockEq(Lock memory _lock1, Lock memory _lock2) internal pure returns (bool) {
        return _lock1.startTime == _lock2.startTime && _lock1.cliff == _lock2.cliff && _lock1.endTime == _lock2.endTime
            && _lock1.allocation == _lock2.allocation;
    }
}
