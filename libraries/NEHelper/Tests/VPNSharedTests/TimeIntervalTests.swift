//
//  TimeIntervalTests.swift
//  ProtonVPN - Created on 2020-11-18.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest

class TimeIntervalTests: XCTestCase {
    
    func testRendersasColonSeparatedString() throws {
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour

        // swiftlint:disable comma
        XCTAssertEqual(TimeInterval(1).asColonSeparatedString,              "00:00:01")
        XCTAssertEqual(minute.asColonSeparatedString,                       "00:01:00")
        XCTAssertEqual(TimeInterval(61).asColonSeparatedString,             "00:01:01")
        XCTAssertEqual(TimeInterval(59).asColonSeparatedString,             "00:00:59")
        XCTAssertEqual(hour.asColonSeparatedString,                         "01:00:00")
        XCTAssertEqual((hour + 1).asColonSeparatedString,                   "01:00:01")
        XCTAssertEqual((hour + 61).asColonSeparatedString,                  "01:01:01")
        XCTAssertEqual((1 * day + 1 * hour + 61).asColonSeparatedString,    "01:01:01:01")
        XCTAssertEqual((2 * day + 25 * hour + 61 * minute + 30).asColonSeparatedString, "03:02:01:30")
        // swiftlint:enable comma
    }

    func testTruncatesUntilMinimumUnit() {
        XCTAssertEqual(TimeInterval(minutes: 12, seconds: 34).asColonSeparatedString(maxUnit: .day, minUnit: .minute), "12:34")
        XCTAssertEqual(TimeInterval(minutes: 12, seconds: 34).asColonSeparatedString(maxUnit: .day, minUnit: .hour), "00:12:34")
        XCTAssertEqual((TimeInterval(1)).asColonSeparatedString(maxUnit: .day, minUnit: .hour), "00:00:01")
        XCTAssertEqual((TimeInterval(1)).asColonSeparatedString(maxUnit: .day, minUnit: .minute), "00:01")
        XCTAssertEqual((TimeInterval(1)).asColonSeparatedString(maxUnit: .day, minUnit: .second), "01")
    }

    func testFirstUnit() {
        XCTAssertEqual(TimeInterval.days(3).asColonSeparatedString(maxUnit: .hour, minUnit: .hour), "72:00:00")
        XCTAssertEqual(TimeInterval.days(3).asColonSeparatedString(maxUnit: .minute, minUnit: .minute), "4320:00")
        XCTAssertEqual(TimeInterval(90).asColonSeparatedString(maxUnit: .second, minUnit: .second), "90")
    }

    func testPrefixesEmptySegmentsUntilMinimumUnit() {
        XCTAssertEqual(TimeInterval(12).asColonSeparatedString(maxUnit: .day, minUnit: .minute), "00:12")
        XCTAssertEqual(TimeInterval(12).asColonSeparatedString(maxUnit: .day, minUnit: .hour), "00:00:12")
        XCTAssertEqual(TimeInterval(12).asColonSeparatedString(maxUnit: .day, minUnit: .day), "00:00:00:12")
    }
}
