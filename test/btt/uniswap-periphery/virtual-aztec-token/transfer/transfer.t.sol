// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IATPFactory} from "@atp/ATPFactory.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";

import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";

import {console} from "forge-std/console.sol";

contract VirtualAztecTokenTransfer is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_whenTheSenderIsNeitherTheAuctionAddressNorTheStrategyAddress(
        address _caller,
        address _recipient,
        uint256 _amount
    ) public {
        // it should be transferable normally
        vm.assume(_caller != address(auction) && _caller != address(strategy));
        vm.assume(_recipient != address(0));
        vm.assume(_caller != address(0));

        __helper__mint(_caller, _amount);

        vm.prank(_caller);
        virtualAztecToken.transfer(_recipient, _amount);
    }

    function test_GivenTheAztecTokenIsBacked_WhenTheAuctionAddressIsTheSender(
        address _recipient,
        uint256 _totalSupply,
        uint256 _amount
    ) public {
        // it should decrease the total supply
        // it should decrease the balance of the sender
        // it should increase the pending atp balance of the recipient
        vm.assume(_recipient != address(0));
        vm.assume(_recipient != address(this));
        vm.assume(_recipient != address(auction));
        vm.assume(_recipient != address(virtualAztecToken));
        vm.assume(_recipient != virtualAztecToken.FOUNDATION_ADDRESS());
        vm.assume(_amount > 0);
        vm.assume(_totalSupply > _amount);

        mintVirtualAztecTokenIntoAuction(_totalSupply);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);

        vm.prank(address(auction));
        virtualAztecToken.transfer(_recipient, _amount);

        assertEq(virtualAztecToken.pendingAtpBalance(_recipient), _amount);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(auction)), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(this)), 0);
        assertEq(virtualAztecToken.balanceOf(_recipient), 0);

        assertEq(underlyingToken.balanceOf(_recipient), 0);
    }

    // TODO: version with the non signature type
    function test_GivenTheAztecTokenIsBacked_WhenTheAuctionAddressIsTheSenderAndTheRecipientHasAnATPRecipientSet(
        uint256 _toPrivateKey,
        address _beneficiary,
        uint256 _amount,
        uint256 _totalSupply
    ) public {
        // it should decrease the total supply
        // it should decrease the balance of the sender
        // it should mint an ATP to the listed recipient
        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != address(this));
        vm.assume(_beneficiary != address(auction));
        vm.assume(_beneficiary != address(virtualAztecToken));
        vm.assume(_amount > 0);
        vm.assume(_totalSupply > _amount);

        _toPrivateKey = boundPrivateKey(_toPrivateKey);

        mintVirtualAztecTokenIntoAuction(_totalSupply);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);

        uint256 deadline = block.timestamp + 1000;
        address owner = vm.addr(_toPrivateKey);

        // If the owner is the foundation address, it will fail as transfer behaves differently
        vm.assume(owner != virtualAztecToken.FOUNDATION_ADDRESS());


        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_toPrivateKey, owner, _beneficiary, deadline);

        vm.expectEmit(true, true, true, true, address(virtualAztecToken));
        emit IVirtualAztecToken.AtpBeneficiarySet(owner, _beneficiary);
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, deadline, signature, bytes(""));

        // predict the atp address - using the new expected _beneficiary
        address atpAddress;
        if (_amount >= virtualAztecToken.MIN_STAKE_AMOUNT()) {
            atpAddress = atpFactory.predictNCATPAddress(
                _beneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        } else {
            atpAddress = atpFactory.predictLATPAddress(
                _beneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        }

        vm.prank(address(auction));
        virtualAztecToken.transfer(owner, _amount);

        assertEq(virtualAztecToken.atpBeneficiaries(owner), _beneficiary);
        assertEq(virtualAztecToken.pendingAtpBalance(owner), _amount);

        vm.expectEmit(true, true, true, true, address(atpFactory));
        emit IATPFactory.ATPCreated(_beneficiary, atpAddress, _amount);
        vm.prank(owner);
        virtualAztecToken.sweepIntoAtp();

        assertEq(virtualAztecToken.totalSupply(), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(auction)), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(this)), 0);
        assertEq(virtualAztecToken.balanceOf(owner), 0);

        assertEq(underlyingToken.balanceOf(address(atpAddress)), _amount);
        assertEq(underlyingToken.balanceOf(owner), 0);
    }

    function test_GivenTheAztecTokenIsBacked_WhenTheStrategyAddressIsTheSender(
        address _recipient,
        uint256 _totalSupply,
        uint256 _amount
    ) public {
        // it should decrease the total supply
        // it should decrease the balance of the sender
        // it should transfer the underlying tokens to the recipient
        vm.assume(_recipient != address(0));
        vm.assume(_recipient != address(this));
        vm.assume(_recipient != address(auction));
        vm.assume(_recipient != address(strategy));
        vm.assume(_recipient != address(virtualAztecToken));

        vm.assume(_amount > 0);
        vm.assume(_totalSupply > _amount);

        mintVirtualAztecTokenIntoStrategy(_totalSupply);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);

        vm.prank(address(strategy));
        virtualAztecToken.transfer(_recipient, _amount);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(strategy)), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(this)), 0);
        assertEq(virtualAztecToken.balanceOf(_recipient), 0);

        assertEq(underlyingToken.balanceOf(address(strategy)), 0);
        assertEq(underlyingToken.balanceOf(_recipient), _amount);
    }

    function test_GivenTheAztecTokenIsBacked_WhenTheStrategyAddressIsTheSender_RecipientIsTheAuctionAddress(
        uint256 _totalSupply,
        uint256 _amount
    ) public {
        // it should move the virtual tokens, not the underlying tokens
        vm.assume(_amount > 0);
        vm.assume(_totalSupply > _amount);

        mintVirtualAztecTokenIntoStrategy(_totalSupply);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);

        vm.prank(address(strategy));
        virtualAztecToken.transfer(address(auction), _amount);

        assertEq(virtualAztecToken.totalSupply(), _totalSupply);
        assertEq(virtualAztecToken.balanceOf(address(strategy)), _totalSupply - _amount);
        assertEq(virtualAztecToken.balanceOf(address(this)), 0);
        assertEq(virtualAztecToken.balanceOf(address(auction)), _amount);

        assertEq(underlyingToken.balanceOf(address(strategy)), 0);
        assertEq(underlyingToken.balanceOf(address(auction)), 0);
    }
}
