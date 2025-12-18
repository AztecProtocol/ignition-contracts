// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";
import {AttestationProvider} from "src/soulbound/providers/AttestationProvider.sol";

contract AttestationBase is Test {
    AttestationProvider public attestationProvider;

    function setUp() public virtual {
        attestationProvider = new AttestationProvider(address(this), address(0));
    }
}
