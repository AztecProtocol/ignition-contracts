// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract AdminMintTest is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_TheCallerIsNotTheAdmin(address _caller, address _to, uint8 _tokenId) public {
        // It should revert
        vm.assume(_caller != address(this));
        vm.assume(_tokenId <= uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL));

        IIgnitionParticipantSoulbound.TokenId tokenId = IIgnitionParticipantSoulbound.TokenId(_tokenId);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.adminMint(_to, tokenId, gridTileId);

        assertEq(soulboundToken.balanceOf(_to, uint256(_tokenId)), 0);
    }

    function test_Revert_WhenTheTokenIdIsOutOfRange(address _to, uint256 _tokenId) public {
        vm.assume(_tokenId > uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL));

        // Use call in order to bypass solidity enum range check
        (bool _success,) = address(soulboundToken)
            .call(abi.encodeWithSelector(soulboundToken.adminMint.selector, _to, _tokenId, gridTileId));
        assertEq(_success, false);

        assertEq(soulboundToken.balanceOf(_to, uint256(_tokenId)), 0);
    }

    function test_WhenTheTokenIdIsInRangeAndTheCallerIsTheAdmin(address _to, uint256 _tokenId) public {
        // It should mint the token
        vm.assume(_tokenId <= uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL));
        vm.assume(_to.code.length == 0);
        vm.assume(_to != address(0));

        IIgnitionParticipantSoulbound.TokenId tokenId = IIgnitionParticipantSoulbound.TokenId(_tokenId);

        soulboundToken.adminMint(_to, tokenId, gridTileId);

        assertEq(soulboundToken.balanceOf(_to, uint256(_tokenId)), 1);
    }

    function test_RevertWhen_TheAddressHasAlreadyMinted(address _to, uint256 _tokenId) public {
        // It should revert
        vm.assume(_tokenId <= uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL));
        vm.assume(_to.code.length == 0);
        vm.assume(_to != address(0));

        IIgnitionParticipantSoulbound.TokenId tokenId = IIgnitionParticipantSoulbound.TokenId(_tokenId);

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            _to,
            /*operator*/
            address(this),
            tokenId,
            gridTileId
        );
        soulboundToken.adminMint(_to, tokenId, gridTileId);

        assertEq(soulboundToken.balanceOf(_to, uint256(_tokenId)), 1);
        assertEq(soulboundToken.gridTileId(_to), gridTileId);

        vm.expectRevert(
            abi.encodeWithSelector(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__AlreadyMinted.selector)
        );
        soulboundToken.adminMint(_to, tokenId, gridTileId);

        assertEq(soulboundToken.balanceOf(_to, uint256(_tokenId)), 1);
    }
}
