// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";

import {console} from "forge-std/console.sol";  

contract SetAtpBeneficiary is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    /// Msg.sender variants

    function test_whenTheSetBeneficiaryIsTheZeroAddress(address _sender) public givenScreeningProviderSucceeds {
        // it should revert with ZeroAddress

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        vm.prank(_sender);
        virtualAztecToken.setAtpBeneficiary(address(0), bytes(""));
    }

    function test_whenTheSetBeneficaryIsNotTheZeroAddress(address _sender, address _beneficiary)
        public
        givenScreeningProviderSucceeds
    {
        // it should emit AtpBeneficiarySet Event
        // it should set the atp beneficiary

        vm.assume(_sender != address(0));
        vm.assume(_beneficiary != address(0));

        vm.expectEmit(true, true, true, true, address(virtualAztecToken));
        emit IVirtualAztecToken.AtpBeneficiarySet(_sender, _beneficiary);
        vm.prank(_sender);
        virtualAztecToken.setAtpBeneficiary(_beneficiary, bytes(""));

        assertEq(virtualAztecToken.atpBeneficiaries(_sender), _beneficiary);
    }

    function test_whenScreeningProviderFails(address _sender, address _beneficiary) public givenScreeningProviderFails {
        // it should revert with ScreeningFailed

        vm.assume(_sender != address(0));
        vm.assume(_beneficiary != address(0));

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ScreeningFailed.selector));
        vm.prank(_sender);
        virtualAztecToken.setAtpBeneficiary(_beneficiary, bytes(""));

        // Not updated
        assertEq(virtualAztecToken.atpBeneficiaries(_sender), address(0));
    }

    // Signautre variants
    function test_whenSetBeneficiaryWithSignatureBeneficaryIsTheZeroAddress(address _owner, address _sender)
        public
        givenScreeningProviderSucceeds
    {
        vm.assume(_owner != address(0));
        vm.assume(_sender != address(0));
        uint256 deadline = block.timestamp + 1000;

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        vm.prank(_sender);
        virtualAztecToken.setAtpBeneficiaryWithSignature(_owner, address(0), deadline, emptySignature, bytes(""));
    }

    function test_whenSetBeneficiaryWithSignatureOwnerIsTheZeroAddress(address _beneficiary, address _sender)
        public
        givenScreeningProviderSucceeds
    {
        vm.assume(_beneficiary != address(0));
        vm.assume(_sender != address(0));
        uint256 deadline = block.timestamp + 1000;

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        vm.prank(_sender);
        virtualAztecToken.setAtpBeneficiaryWithSignature(address(0), _beneficiary, deadline, emptySignature, bytes(""));
    }

    ///@notice mess up the created signature with a mask
    function test_set_whenSetBeneficiaryWithSignatureIsInvalid(
        uint256 _signerKey,
        uint256 _invalidSigMask,
        address _beneficiary
    ) public givenScreeningProviderSucceeds {
        // it should set the beneficiary successfully

        vm.assume(_beneficiary != address(0));
        vm.assume(_invalidSigMask != uint256(0));

        uint256 deadline = block.timestamp + 1000;

        _signerKey = boundPrivateKey(_signerKey);

        address owner = vm.addr(_signerKey);

        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_signerKey, owner, _beneficiary, deadline);
        signature.r = bytes32(type(uint256).max);

        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, deadline, signature, bytes(""));

        // the beneficiary has not been updated
        assertEq(virtualAztecToken.atpBeneficiaries(owner), address(0));
    }

    function test_set_whenSetBeneficiaryWithSignatureIsDifferent(
        uint256 _signerKey,
        uint256 _wrongSignerKey,
        uint256 _invalidSigMask,
        address _beneficiary
    ) public givenScreeningProviderSucceeds {
        // it should set the beneficiary successfully
        vm.assume(_wrongSignerKey != _signerKey);

        vm.assume(_beneficiary != address(0));
        vm.assume(_invalidSigMask != uint256(0));

        uint256 deadline = block.timestamp + 1000;

        _signerKey = boundPrivateKey(_signerKey);
        _wrongSignerKey = boundPrivateKey(_wrongSignerKey);

        address owner = vm.addr(_signerKey);
        address wrongOwner = vm.addr(_wrongSignerKey);
        vm.assume(wrongOwner != owner);

        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_wrongSignerKey, owner, _beneficiary, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__InvalidEIP712SetBeneficiarySiganture.selector)
        );
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, deadline, signature, bytes(""));

        // the beneficiary has not been updated
        assertEq(virtualAztecToken.atpBeneficiaries(owner), address(0));
    }

    modifier givenSignatureIsValid() {
        _;
    }

    function test_whenSignatureIsValidButScreeningProviderFails(uint256 _signerKey, address _beneficiary)
        public
        givenScreeningProviderFails
        givenSignatureIsValid
    {
        // it should emit AtpBeneficiarySet Event
        // it should set the atp beneficiary
        vm.assume(_beneficiary != address(0));
        uint256 deadline = block.timestamp + 1000;

        _signerKey = boundPrivateKey(_signerKey);

        address owner = vm.addr(_signerKey);

        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_signerKey, owner, _beneficiary, deadline);

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ScreeningFailed.selector));
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, deadline, signature, bytes(""));

        // Not updated
        assertEq(virtualAztecToken.atpBeneficiaries(owner), address(0));
    }

    function test_whenSignatureIsValidButDeadlineHasBeenExceeded(uint256 _signerKey, address _beneficiary, uint32 _deadline, uint32 _timeNow)
        public
        givenScreeningProviderSucceeds
        givenSignatureIsValid
    {
        // it should revert with SignatureDeadlineExpired

        vm.assume(_beneficiary != address(0));
        vm.assume(_deadline < type(uint32).max - 2);

        // Deadline should be in the past
        _timeNow = uint32(bound(_timeNow, _deadline + 1, type(uint32).max));

        vm.warp(_timeNow);

        _signerKey = boundPrivateKey(_signerKey);

        address owner = vm.addr(_signerKey);

        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_signerKey, owner, _beneficiary, _deadline);

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__SignatureDeadlineExpired.selector));
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, _deadline, signature, bytes(""));

        // Not updated
        assertEq(virtualAztecToken.atpBeneficiaries(owner), address(0));
    }

    function test_set_whenSetBeneficiaryWithSignatureIsValid(uint256 _signerKey, address _beneficiary)
        public
        givenScreeningProviderSucceeds
        givenSignatureIsValid
    {
        // it should emit AtpBeneficiarySet Event
        // it should set the atp beneficiary
        vm.assume(_beneficiary != address(0));

        _signerKey = boundPrivateKey(_signerKey);
        uint256 deadline = block.timestamp + 1000;

        address owner = vm.addr(_signerKey);

        IVirtualAztecToken.Signature memory signature = helper__generateSignature(_signerKey, owner, _beneficiary, deadline);

        vm.expectEmit(true, true, true, true, address(virtualAztecToken));
        emit IVirtualAztecToken.AtpBeneficiarySet(owner, _beneficiary);
        virtualAztecToken.setAtpBeneficiaryWithSignature(owner, _beneficiary, deadline, signature, bytes(""));

        // the beneficiary has been updated
        assertEq(virtualAztecToken.atpBeneficiaries(owner), address(_beneficiary));
    }
}
