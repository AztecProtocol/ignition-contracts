// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Base} from "./Base.sol";

contract TGEPayloadTest is Base {
    function test_getURI() public {
        assertEq(tgePayload.getURI(), "https://github.com/AztecProtocol/ignition-contracts/");
    }
}
