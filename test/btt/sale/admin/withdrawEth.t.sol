// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract WithdrawEth is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfWithdrawEthIsNotOwner(address _caller, address _to) external {
        // it reverts

        vm.assume(_caller != FOUNDATION_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.withdrawETH(_to, 1);
    }

    function test_WhenCallerOfWithdrawEthIsOwner(address _to, uint128 _amount) external {
        // it withdraws ETH from the contract
        // it emits a {ETHWithdrawn} event
        vm.assume(_to > address(0x40)); // avoid precompiles
        assumeAddress(_to);
        vm.assume(_amount > 0);

        // Ensure _to can receive ETH by checking if it's an EOA or has a receive/fallback function
        // Skip addresses that are contracts without receive/fallback
        if (_to.code.length > 0) {
            // Give it a small amount first to test if it can receive ETH
            (bool canReceive,) = _to.call{value: 1}("");
            vm.assume(canReceive);
        }

        vm.deal(address(genesisSequencerSale), _amount);

        uint256 genesisSequencerSaleBalance = address(genesisSequencerSale).balance;
        uint256 toBalanceBefore = address(_to).balance;

        vm.expectEmit(true, true, true, true);
        emit IGenesisSequencerSale.ETHWithdrawn(_to, genesisSequencerSaleBalance);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.withdrawETH(_to, genesisSequencerSaleBalance);

        assertEq(address(genesisSequencerSale).balance, 0);
        assertEq(address(_to).balance, toBalanceBefore + genesisSequencerSaleBalance);
    }

    function test_WhenTheRecipientCannotReceiveETH() external {
        uint256 genesisSequencerSaleBalance = address(genesisSequencerSale).balance;
        // it reverts
        vm.prank(FOUNDATION_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(IGenesisSequencerSale.GenesisSequencerSale__ETHTransferFailed.selector));
        genesisSequencerSale.withdrawETH(address(saleToken), genesisSequencerSaleBalance);
    }

    function test_sendToFoundationAddress(uint128 _amount) external {
        // it withdraws ETH from the contract
        // it emits a {ETHWithdrawn} event

        vm.assume(_amount > 0);

        vm.deal(address(genesisSequencerSale), _amount);

        uint256 genesisSequencerSaleBalance = address(genesisSequencerSale).balance;
        uint256 foundationBalanceBefore = address(FOUNDATION_ADDRESS).balance;

        vm.expectEmit(true, true, true, true);
        emit IGenesisSequencerSale.ETHWithdrawn(FOUNDATION_ADDRESS, genesisSequencerSaleBalance);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.withdrawETH(FOUNDATION_ADDRESS, genesisSequencerSaleBalance);

        assertEq(address(genesisSequencerSale).balance, 0);
        assertEq(address(FOUNDATION_ADDRESS).balance, foundationBalanceBefore + genesisSequencerSaleBalance);
    }
}
