// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract AdminBatchMintTest is SoulboundBase {
    mapping(address => bool) public uniqueAddresses;
    mapping(uint256 => bool) public uniqueGridTileIds;

    function setUp() public override {
        super.setUp();
    }

    struct FuzzBatchMintParams {
        address to;
        uint8 tokenId;
        uint256 gridTileId;
    }

    modifier givenTokenIdsAreInRange(FuzzBatchMintParams[] memory _params) {
        for (uint256 i = 0; i < _params.length; i++) {
            _params[i].tokenId =
                uint8(bound(uint8(_params[i].tokenId), uint8(0), uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL)));
        }
        _;
    }

    modifier givenSendingToEOAs(FuzzBatchMintParams[] memory _params) {
        for (uint256 i = 0; i < _params.length; i++) {
            // Dont edit these addresses
            vm.assume(
                _params[i].to != address(this) && _params[i].to != address(soulboundToken)
                    && _params[i].to != address(vm)
            );
            vm.etch(_params[i].to, "");
        }
        _;
    }

    // Make sure we are not etching precompiles or sending to them
    modifier givenSendingToValidAddresses(FuzzBatchMintParams[] memory _params) {
        for (uint256 i = 0; i < _params.length; i++) {
            _params[i].to = address(uint160(bound(uint160(_params[i].to), 100, type(uint160).max)));
        }
        _;
    }

    function assertUniqueAddressesAndGridTileIds(FuzzBatchMintParams[] memory _params) public returns (bool) {
        for (uint256 i = 0; i < _params.length; i++) {
            // Check address
            if (uniqueAddresses[_params[i].to]) {
                return false;
            }
            uniqueAddresses[_params[i].to] = true;

            // Check grid token id
            if (uniqueGridTileIds[_params[i].gridTileId]) {
                return false;
            }
            uniqueGridTileIds[_params[i].gridTileId] = true;
        }
        return true;
    }

    function convertFuzzBatchMintParams(FuzzBatchMintParams[] memory _params)
        public
        pure
        returns (address[] memory, IIgnitionParticipantSoulbound.TokenId[] memory, uint256[] memory)
    {
        address[] memory to = new address[](_params.length);
        IIgnitionParticipantSoulbound.TokenId[] memory tokenId =
            new IIgnitionParticipantSoulbound.TokenId[](_params.length);
        uint256[] memory gridTileId = new uint256[](_params.length);

        for (uint256 i = 0; i < _params.length; i++) {
            to[i] = _params[i].to;
            tokenId[i] = IIgnitionParticipantSoulbound.TokenId(_params[i].tokenId);
            gridTileId[i] = _params[i].gridTileId;
        }
        return (to, tokenId, gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_RevertWhen_TheCallerIsNotTheAdmin(address _caller, FuzzBatchMintParams[] memory _params) public {
        vm.assume(_caller != address(this));

        for (uint256 i = 0; i < _params.length; i++) {
            _params[i].tokenId =
                uint8(bound(uint8(_params[i].tokenId), uint8(0), uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL)));
        }

        (address[] memory to, IIgnitionParticipantSoulbound.TokenId[] memory tokenId, uint256[] memory gridTileId) =
            convertFuzzBatchMintParams(_params);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.adminBatchMint(to, tokenId, gridTileId);

        for (uint256 i = 0; i < _params.length; i++) {
            assertEq(soulboundToken.balanceOf(_params[i].to, uint256(_params[i].tokenId)), 0);
        }
    }

    /// forge-config: default.fuzz.runs = 10
    function test_Revert_WhenTheTokenIdIsOutOfRange(address[] calldata _to, uint8[] memory _tokenId) public {
        vm.assume(_to.length == _tokenId.length);
        vm.assume(_to.length > 0);

        for (uint256 i = 0; i < _to.length; i++) {
            _tokenId[i] =
                uint8(bound(_tokenId[i], uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL) + 1, type(uint8).max));
        }

        // Use call in order to bypass solidity enum range check
        (bool success,) =
            address(soulboundToken).call(abi.encodeWithSelector(soulboundToken.adminBatchMint.selector, _to, _tokenId));
        assertEq(success, false);

        for (uint256 i = 0; i < _to.length; i++) {
            assertEq(soulboundToken.balanceOf(_to[i], uint256(_tokenId[i])), 0);
        }
    }

    /// forge-config: default.fuzz.runs = 10
    function test_RevertWhen_TheTokenIdsAndAddressesAreOfDifferentLengths(
        address[] memory _to,
        uint8[] calldata _tokenId
    ) external {
        vm.assume(_to.length != _tokenId.length);

        IIgnitionParticipantSoulbound.TokenId[] memory tokenIds =
            new IIgnitionParticipantSoulbound.TokenId[](_tokenId.length);

        uint256 gridTileIdCounter = 1;
        uint256[] memory gridTileIds = new uint256[](_tokenId.length);
        for (uint256 i = 0; i < _tokenId.length; i++) {
            tokenIds[i] = IIgnitionParticipantSoulbound.TokenId(
                bound(_tokenId[i], uint8(0), uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL))
            );
            gridTileIds[i] = gridTileIdCounter++;
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidInputLength.selector
            )
        );
        soulboundToken.adminBatchMint(_to, tokenIds, gridTileIds);
    }

    function test_RevertWhen_TheGridgridTileIdsAndAddressesAreOfDifferentLengths(
        address[] memory _to,
        uint8[] memory _tokenId,
        uint256[] memory _gridTileId
    ) public {
        vm.assume(_to.length != _tokenId.length);

        IIgnitionParticipantSoulbound.TokenId[] memory tokenIds =
            new IIgnitionParticipantSoulbound.TokenId[](_tokenId.length);

        for (uint256 i = 0; i < _tokenId.length; i++) {
            tokenIds[i] = IIgnitionParticipantSoulbound.TokenId(
                bound(_tokenId[i], uint8(0), uint8(IIgnitionParticipantSoulbound.TokenId.GENERAL))
            );
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidInputLength.selector
            )
        );
        soulboundToken.adminBatchMint(_to, tokenIds, _gridTileId);
    }

    function test_WhenTheTokenIdIsInRangeAndTheCallerIsTheAdmin(FuzzBatchMintParams[] memory _params)
        public
        givenTokenIdsAreInRange(_params)
        givenSendingToValidAddresses(_params)
        givenSendingToEOAs(_params)
    {
        vm.assume(assertUniqueAddressesAndGridTileIds(_params));
        vm.assume(_params.length > 0);

        (address[] memory to, IIgnitionParticipantSoulbound.TokenId[] memory tokenId, uint256[] memory gridTileId) =
            convertFuzzBatchMintParams(_params);
        soulboundToken.adminBatchMint(to, tokenId, gridTileId);

        for (uint256 i = 0; i < _params.length; i++) {
            assertEq(soulboundToken.balanceOf(_params[i].to, uint256(uint8(_params[i].tokenId))), 1);
            assertEq(soulboundToken.gridTileId(_params[i].to), _params[i].gridTileId);
        }
    }

    function test_RevertWhen_TheAddressHasAlreadyMinted(FuzzBatchMintParams[] memory _params)
        public
        givenTokenIdsAreInRange(_params)
        givenSendingToValidAddresses(_params)
        givenSendingToEOAs(_params)
    {
        vm.assume(assertUniqueAddressesAndGridTileIds(_params));
        vm.assume(_params.length > 0);

        for (uint256 i = 0; i < _params.length; i++) {
            _params[i].to = address(uint160(bound(uint160(_params[i].to), 100, type(uint160).max)));
        }

        (address[] memory to, IIgnitionParticipantSoulbound.TokenId[] memory tokenId, uint256[] memory gridTileId) =
            convertFuzzBatchMintParams(_params);

        soulboundToken.adminBatchMint(to, tokenId, gridTileId);

        for (uint256 i = 0; i < _params.length; i++) {
            assertEq(soulboundToken.balanceOf(_params[i].to, uint256(uint8(_params[i].tokenId))), 1);
            assertEq(soulboundToken.gridTileId(_params[i].to), _params[i].gridTileId);
        }

        vm.expectRevert(
            abi.encodeWithSelector(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__AlreadyMinted.selector)
        );
        soulboundToken.adminBatchMint(to, tokenId, gridTileId);

        for (uint256 i = 0; i < _params.length; i++) {
            assertEq(soulboundToken.balanceOf(_params[i].to, uint256(uint8(_params[i].tokenId))), 1);
            assertEq(soulboundToken.gridTileId(_params[i].to), _params[i].gridTileId);
        }
    }
}
