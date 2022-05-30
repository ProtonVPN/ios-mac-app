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
import vpncore

class TimeIntervalTests: XCTestCase {
    
    func testRendersAsString() throws {
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour

        XCTAssertEqual(TimeInterval(1).asString,              "00:00:01")
        XCTAssertEqual(minute.asString,                       "00:01:00")
        XCTAssertEqual(TimeInterval(61).asString,             "00:01:01")
        XCTAssertEqual(TimeInterval(59).asString,             "00:00:59")
        XCTAssertEqual(hour.asString,                         "01:00:00")
        XCTAssertEqual((hour + 1).asString,                   "01:00:01")
        XCTAssertEqual((hour + 61).asString,                  "01:01:01")
        XCTAssertEqual((1 * day + 1 * hour + 61).asString,    "01:01:01:01")
        XCTAssertEqual((2 * day + 25 * hour + 61 * minute + 30).asString, "03:02:01:30")
    }

}
