// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";
import {IATPFactory} from "@atp/ATPFactory.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";

contract SweepIntoAtpTest is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_whenTheSenderHasNoBalance(address _sender) public {
        // it should revert

        vm.expectRevert();
        vm.prank(_sender);
        virtualAztecToken.sweepIntoAtp();
    }

    function test_whenTheSenderHasBalance(address _recipient, uint256 _totalSupply, uint256 _amount) public {
        // it should create an atp
        // if amount > MIN_STAKE_AMOUNT, it should create a staking atp
        // if amount < MIN_STAKE_AMOUNT, it should create a normal atp
        // it should transfer the underlying tokens to the atp
        // it should decrease the total supply
        // it should decrease the balance of the sender
        // it should increase the balance of the recipient
        // it should increase the balance of the atp

        vm.assume(_recipient != address(0));
        vm.assume(_recipient != address(this));
        vm.assume(_recipient != address(auction));
        vm.assume(_recipient != address(virtualAztecToken));
        vm.assume(_recipient != address(foundationAddress));
        vm.assume(_amount > 0);
        vm.assume(_totalSupply > _amount);

        mintVirtualAztecTokenIntoAuction(_totalSupply);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);

        // Transfer from the auction to the sender
        vm.prank(address(auction));
        virtualAztecToken.transfer(_recipient, _amount);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply - _amount);

        // Assert the pending atp balance of the sender
        assertEq(virtualAztecToken.pendingAtpBalance(_recipient), _amount);

        // Sweep into atp
        address atpAddress;
        if (_amount >= virtualAztecToken.MIN_STAKE_AMOUNT()) {
            atpAddress = atpFactory.predictNCATPAddress(
                _recipient, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        } else {
            atpAddress = atpFactory.predictLATPAddress(
                _recipient, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        }

        vm.expectEmit(true, true, true, true, address(atpFactory));
        emit IATPFactory.ATPCreated(_recipient, atpAddress, _amount);
        vm.prank(_recipient);
        virtualAztecToken.sweepIntoAtp();

        assertEq(virtualAztecToken.totalSupply(), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(auction)), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(this)), 0);
        assertEq(virtualAztecToken.balanceOf(_recipient), 0);

        assertEq(underlyingToken.balanceOf(address(atpAddress)), _amount);
        assertEq(underlyingToken.balanceOf(_recipient), 0);
    }
}
