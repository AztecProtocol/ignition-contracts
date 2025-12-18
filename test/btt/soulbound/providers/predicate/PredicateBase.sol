// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {PredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {MockPredicateManager} from "test/mocks/soulbound/MockPredicateManager.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";
import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";

abstract contract PredicateBase is Test {
    PredicateProvider public predicateProvider;

    MockPredicateManager public predicateManager;

    address public consumer = makeAddr("consumer");
    address public predicateSigner = makeAddr("predicateSigner");
    string public policyID = "test";

    function setUp() public virtual {
        predicateManager = new MockPredicateManager();
        predicateProvider = new PredicateProvider(address(this), address(predicateManager), policyID);
        predicateProvider.setConsumer(consumer);
    }

    function makePredicateAttestation() internal view returns (PredicateMessage memory) {
        uint256 expireByTime = block.timestamp + 1 hours;
        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = predicateSigner;
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("");

        PredicateMessage memory message = PredicateMessage({
            taskId: "test", expireByTime: expireByTime, signerAddresses: signerAddresses, signatures: signatures
        });

        return message;
    }

    function makePredicateSucceed() internal {
        vm.prank(consumer);
        predicateManager.setPolicyResponse(policyID, true);
    }

    function makePredicateFail() internal {
        vm.prank(consumer);
        predicateManager.setPolicyResponse(policyID, false);
    }
}
