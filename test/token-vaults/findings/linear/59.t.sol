// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";

import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Staking} from "test/token-vaults/mocks/Staking.sol";
import {
    LATP,
    ILATP,
    ILATPCore,
    IATPCore,
    ATPFactory,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams,
    StakerVersion
} from "test/token-vaults/Importer.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

contract AttackStaker is FakeStaker {
    constructor(Staking _staking) FakeStaker(_staking) {}

    uint256 public testSuccess = 0;

    function getAllTokens(address target, uint256 amount) external onlyATP {
        STAKING.unstake(target, amount);
    }

    function test() external override(FakeStaker) {}
}

contract Issue59Test is LATPTestBase {
    ILATP public atp;

    function setUp() public override(LATPTestBase) {
        super.setUp();
    }

    function test_upgradeStakerAttack() external {
        atp = atpFactory.createLATP(
            address(this),
            1000e18,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 0, lockDuration: 1000})
            })
        );

        Staking staking = FakeStaker(registry.getStakerImplementation(StakerVersion.wrap(1))).STAKING();

        address expectedStakerBefore = registry.getStakerImplementation(StakerVersion.wrap(0));
        address expectedStakerAfter = registry.getStakerImplementation(fakeStakerVersion);

        assertEq(atp.getStaker().getImplementation(), expectedStakerBefore);

        // attack
        AttackStaker attackStakerImpl = new AttackStaker(staking);
        address attackerDeposit = address(0xeee);

        // move tokens into staking
        aztec.mint(address(this), 1000e18);
        aztec.approve(address(staking), 1000e18);
        staking.stake(address(atp.getStaker()), 1000e18);

        uint256 amountToTake = 1000e18;

        bytes memory data = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            address(attackStakerImpl),
            abi.encodeWithSelector(attackStakerImpl.getAllTokens.selector, attackerDeposit, amountToTake)
        );
        assertEq(token.balanceOf(attackerDeposit), 0);
        emit log_named_decimal_uint("attacker balance", token.balanceOf(attackerDeposit), 18);

        // The data is not used anymore, so we cannot use it to upgrade maliciously.
        atp.upgradeStaker(fakeStakerVersion);

        emit log_named_decimal_uint("attacker balance", token.balanceOf(attackerDeposit), 18);

        assertEq(token.balanceOf(attackerDeposit), 0, "attacker balance should be 0");
        assertEq(atp.getStaker().getImplementation(), expectedStakerAfter, "staker implementation should be upgraded");
    }
}
