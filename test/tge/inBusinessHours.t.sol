// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TGEPayload} from "src/tge/TGEPayload.sol";

import {Base} from "./Base.sol";

contract InBusinessHoursTest is Base {
    function test_succeedsInBusinessHours() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Tuesday at 10:00 CET (within business hours)
        // Tuesday is day 1, we need to find a Tuesday after jan1_2026_cet
        // Jan 1, 2026 is Thursday (day 3), so Tuesday is 5 days later (Jan 6, 2026)
        uint256 tuesdayAt10CET = jan1_2026_cet + 5 days + 10 hours;
        vm.warp(tuesdayAt10CET);

        // This should succeed
        tgePayload.getActions();
    }

    function test_failsBeforeStartOfWorkday() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Tuesday at 7:00 CET (before business hours start at 8:00)
        uint256 tuesdayAt7CET = jan1_2026_cet + 5 days + 7 hours;
        vm.warp(tuesdayAt7CET);

        uint256 expectedSecondsSinceMidnight = 7 hours;
        uint256 expectedDayOfWeek = 1; // Tuesday

        vm.expectRevert(
            abi.encodeWithSelector(
                TGEPayload.OutsideBusinessHours.selector, expectedSecondsSinceMidnight, expectedDayOfWeek
            )
        );
        tgePayload.getActions();
    }

    function test_failsAfterEndOfWorkday() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Tuesday at 16:00 CET (after business hours end at 15:00)
        uint256 tuesdayAt16CET = jan1_2026_cet + 5 days + 16 hours;
        vm.warp(tuesdayAt16CET);

        uint256 expectedSecondsSinceMidnight = 16 hours;
        uint256 expectedDayOfWeek = 1; // Tuesday

        vm.expectRevert(
            abi.encodeWithSelector(
                TGEPayload.OutsideBusinessHours.selector, expectedSecondsSinceMidnight, expectedDayOfWeek
            )
        );
        tgePayload.getActions();
    }

    function test_failsOnMonday() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Monday at 10:00 CET (valid time, but Monday is before START_DAY=Tuesday)
        // Jan 1, 2026 is Thursday, so Monday is 4 days later (Jan 5, 2026)
        uint256 mondayAt10CET = jan1_2026_cet + 4 days + 10 hours;
        vm.warp(mondayAt10CET);

        uint256 expectedSecondsSinceMidnight = 10 hours;
        uint256 expectedDayOfWeek = 0; // Monday

        vm.expectRevert(
            abi.encodeWithSelector(
                TGEPayload.OutsideBusinessHours.selector, expectedSecondsSinceMidnight, expectedDayOfWeek
            )
        );
        tgePayload.getActions();
    }

    function test_failsOnFriday() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Friday at 10:00 CET (valid time, but Friday is after END_DAY=Thursday)
        // Jan 1, 2026 is Thursday, so Friday is 1 day later (Jan 2, 2026)
        uint256 fridayAt10CET = jan1_2026_cet + 1 days + 10 hours;
        vm.warp(fridayAt10CET);

        uint256 expectedSecondsSinceMidnight = 10 hours;
        uint256 expectedDayOfWeek = 4; // Friday

        vm.expectRevert(
            abi.encodeWithSelector(
                TGEPayload.OutsideBusinessHours.selector, expectedSecondsSinceMidnight, expectedDayOfWeek
            )
        );
        tgePayload.getActions();
    }

    function test_failsOnWeekend() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Warp to a Saturday at 10:00 CET
        // Jan 1, 2026 is Thursday, so Saturday is 2 days later (Jan 3, 2026)
        uint256 saturdayAt10CET = jan1_2026_cet + 2 days + 10 hours;
        vm.warp(saturdayAt10CET);

        uint256 expectedSecondsSinceMidnight = 10 hours;
        uint256 expectedDayOfWeek = 5; // Saturday

        vm.expectRevert(
            abi.encodeWithSelector(
                TGEPayload.OutsideBusinessHours.selector, expectedSecondsSinceMidnight, expectedDayOfWeek
            )
        );
        tgePayload.getActions();
    }

    function test_warpToNextBusinessHourWorks() public {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();

        // Start on a Saturday at 10:00 CET
        uint256 saturdayAt10CET = jan1_2026_cet + 2 days + 10 hours;
        vm.warp(saturdayAt10CET);

        // This should fail
        vm.expectRevert();
        tgePayload.getActions();

        // Warp to next business hour
        warpToNextBusinessHour();

        // Now it should succeed
        tgePayload.getActions();
    }

    function testFuzz_succeedsWithinBusinessHours(uint256 _weekOffset, uint256 _dayOffset, uint256 _secondsIntoWorkday)
        public
    {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();
        uint256 startOfWorkday = tgePayload.START_OF_WORKDAY();
        uint256 endOfWorkday = tgePayload.END_OF_WORKDAY();

        // Bound inputs to valid ranges
        // _weekOffset: test across multiple weeks (0-100 weeks)
        _weekOffset = bound(_weekOffset, 0, 100);
        // _dayOffset: Tuesday=5, Wednesday=6, Thursday=7 days after Jan 1 (Thursday)
        // This gives us the first valid week. For subsequent weeks, we add 7*_weekOffset
        _dayOffset = bound(_dayOffset, 5, 7); // 5=Tuesday, 6=Wednesday, 7=Thursday
        // _secondsIntoWorkday: 0 to (endOfWorkday - startOfWorkday - 1) seconds
        _secondsIntoWorkday = bound(_secondsIntoWorkday, 0, endOfWorkday - startOfWorkday - 1);

        uint256 timestamp =
            jan1_2026_cet + (_weekOffset * 7 days) + (_dayOffset * 1 days) + startOfWorkday + _secondsIntoWorkday;

        vm.warp(timestamp);

        // Should succeed - no revert expected
        tgePayload.getActions();
    }

    function testFuzz_failsOutsideBusinessHours(uint256 _weekOffset, uint256 _dayOfWeek, uint256 _secondsSinceMidnight)
        public
    {
        uint256 jan1_2026_cet = tgePayload.JAN_1_2026_CET();
        uint256 startOfWorkday = tgePayload.START_OF_WORKDAY();
        uint256 endOfWorkday = tgePayload.END_OF_WORKDAY();
        uint256 startDay = tgePayload.START_DAY();
        uint256 endDay = tgePayload.END_DAY();

        // Bound week offset
        _weekOffset = bound(_weekOffset, 0, 100);
        // Bound day of week (0-6, Monday=0, Sunday=6)
        _dayOfWeek = bound(_dayOfWeek, 0, 6);
        // Bound seconds since midnight (0 to 23:59:59)
        _secondsSinceMidnight = bound(_secondsSinceMidnight, 0, 1 days - 1);

        // Skip if this would be a valid business hour
        bool validDay = _dayOfWeek >= startDay && _dayOfWeek <= endDay;
        bool validTime = _secondsSinceMidnight >= startOfWorkday && _secondsSinceMidnight < endOfWorkday;
        if (validDay && validTime) {
            return; // Skip valid business hours
        }

        // Calculate days from Jan 1 (Thursday, day 3) to target day of week
        // Jan 1, 2026 is Thursday (day 3). To get to _dayOfWeek:
        // daysToAdd = (_dayOfWeek - 3 + 7) % 7
        uint256 daysToTargetDay = (_dayOfWeek + 7 - 3) % 7;

        uint256 timestamp =
            jan1_2026_cet + (_weekOffset * 7 days) + (daysToTargetDay * 1 days) + _secondsSinceMidnight;

        vm.warp(timestamp);

        // Should fail
        vm.expectRevert(
            abi.encodeWithSelector(TGEPayload.OutsideBusinessHours.selector, _secondsSinceMidnight, _dayOfWeek)
        );
        tgePayload.getActions();
    }
}
