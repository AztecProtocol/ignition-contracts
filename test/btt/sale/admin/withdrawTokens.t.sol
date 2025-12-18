// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract WithdrawTokens is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfWithdrawTokensIsNotOwner(address _caller, address _to, address _token) external {
        // it reverts

        vm.assume(_caller != FOUNDATION_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.withdrawTokens(_to, _token, 1);
    }

    function test_WhenTokenTransferReverts(address _token, address _to) external {
        // it reverts
        vm.assume(_token > address(0x42));

        address token = address(_token);

        // revert on transfer
        vm.etch(token, hex"ff");

        vm.expectRevert();
        genesisSequencerSale.withdrawTokens(_to, token, 1);
    }

    function test_WhenCallerOfWithdrawTokensIsOwner(bytes32 _tokenSalt, uint128 _amount, address _to) external {
        // it withdraws tokens from the contract
        // it emits a {TokensWithdrawn} event

        vm.assume(_amount > 0);
        assumeAddress(_to);
        vm.assume(_to != address(0));

        address token = address(new MockERC20{salt: _tokenSalt}("Test", "TEST"));
        MockERC20(token).mint(address(genesisSequencerSale), _amount);

        uint256 genesisSequencerSaleBalance = MockERC20(token).balanceOf(address(genesisSequencerSale));
        uint256 foundationBalanceBefore = MockERC20(token).balanceOf(address(FOUNDATION_ADDRESS));

        vm.expectEmit(true, true, true, true);
        emit IGenesisSequencerSale.TokensWithdrawn(_to, token, genesisSequencerSaleBalance);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.withdrawTokens(_to, token, genesisSequencerSaleBalance);

        assertEq(MockERC20(token).balanceOf(address(genesisSequencerSale)), 0);
        assertEq(MockERC20(token).balanceOf(address(_to)), foundationBalanceBefore + genesisSequencerSaleBalance);
    }
}
