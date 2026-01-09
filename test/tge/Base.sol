// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {TGEPayload} from "src/tge/TGEPayload.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {StakerVersion} from "@atp/Registry.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {Configuration as GovernanceConfiguration} from "@aztec/governance/interfaces/IGovernance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {IGSE} from "@aztec/governance/GSE.sol";

contract Base is Test {
    uint256 public constant EARLIEST_TIME = 1763042400 + 7776000;

    StakerVersion public constant STAKER_VERSION = StakerVersion.wrap(2);

    Governance public GOVERNANCE = Governance(0x1102471Eb3378FEE427121c9EfcEa452E4B6B75e);
    IGSE public GSE = IGSE(0xa92ecFD0E70c9cd5E5cd76c50Af0F7Da93567a4f);
    IERC20 public AZTEC_TOKEN;

    TGEPayload public tgePayload;

    function setUp() public virtual {
        // Skip tests if not running on mainnet fork
        if (block.chainid != 1) {
            vm.skip(true);
        }

        tgePayload = new TGEPayload();

        AZTEC_TOKEN = tgePayload.AZTEC_TOKEN();
    }

    function warpToNextBusinessHour() internal {
        // Get the business hours config from the payload
        uint256 startOfWorkday = tgePayload.START_OF_WORKDAY();
        uint256 endOfWorkday = tgePayload.END_OF_WORKDAY();
        uint256 startDay = tgePayload.START_DAY();
        uint256 endDay = tgePayload.END_DAY();
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        uint256 timeSinceReference = block.timestamp - jan1_2026_cet;
        uint256 secondsSinceMidnight = timeSinceReference % 1 days;
        uint256 daysSinceReference = timeSinceReference / 1 days;
        uint256 dayOfWeek = (daysSinceReference + 3) % 7;

        // Check if we're already in business hours
        bool validTime = secondsSinceMidnight >= startOfWorkday && secondsSinceMidnight < endOfWorkday;
        bool validDay = dayOfWeek >= startDay && dayOfWeek <= endDay;

        if (validTime && validDay) {
            return; // Already in business hours
        }

        // Calculate how many days until next valid day
        uint256 daysToAdd = 0;
        if (!validDay || (validDay && secondsSinceMidnight >= endOfWorkday)) {
            // Need to move to next valid day
            uint256 nextDay = (dayOfWeek + 1) % 7;
            while (nextDay < startDay || nextDay > endDay) {
                nextDay = (nextDay + 1) % 7;
                daysToAdd++;
            }
            daysToAdd++; // Add the final day to get to the valid day
        }

        // Calculate target timestamp: start of next valid business day
        uint256 midnightToday = block.timestamp - secondsSinceMidnight;
        uint256 targetTimestamp = midnightToday + (daysToAdd * 1 days) + startOfWorkday;

        vm.warp(targetTimestamp);
    }

    function proposeAndExecuteProposal() internal {
        vm.warp(Math.max(block.timestamp, EARLIEST_TIME));

        address proposer = GOVERNANCE.governanceProposer();

        vm.prank(proposer);
        uint256 proposalId = GOVERNANCE.propose(tgePayload);
        uint256 proposalCreationTime = block.timestamp;
        GovernanceConfiguration memory govConfig = GOVERNANCE.getConfiguration();

        vm.warp(block.timestamp + Timestamp.unwrap(govConfig.votingDelay) + 1);

        uint256 powerAtVotingDelay =
            GOVERNANCE.powerAt(address(GSE), Timestamp.wrap(proposalCreationTime) + govConfig.votingDelay);

        vm.prank(address(GSE));
        GOVERNANCE.vote(proposalId, powerAtVotingDelay, true);

        vm.warp(
            block.timestamp + Timestamp.unwrap(govConfig.votingDuration) + Timestamp.unwrap(govConfig.executionDelay)
                + 1
        );

        // Warp to business hours before execution
        warpToNextBusinessHour();

        GOVERNANCE.execute(proposalId);
    }
}
