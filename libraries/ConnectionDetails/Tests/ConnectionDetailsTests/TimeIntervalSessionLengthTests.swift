//
//  Created on 2023-06-08.
//
//  Copyright (c) 2023 Proton AG
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

import XCTest
@testable import ConnectionDetails

final class TimeIntervalSessionLengthTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual(TimeInterval(-1).sessionLengthText, "1 sec")
        XCTAssertEqual(TimeInterval(-59).sessionLengthText, "59 sec")

        XCTAssertEqual(TimeInterval(-(TimeInterval.minute)).sessionLengthText, "1 min")
        XCTAssertEqual(TimeInterval(-(TimeInterval.minute + 1)).sessionLengthText, "1 min 1 sec")
        XCTAssertEqual(TimeInterval(-(TimeInterval.minute + 59)).sessionLengthText, "1 min 59 sec")

        XCTAssertEqual(TimeInterval(-(TimeInterval.hour)).sessionLengthText, "1 hr")
        XCTAssertEqual(TimeInterval(-(TimeInterval.hour + TimeInterval.minute)).sessionLengthText, "1 hr 1 min")
        XCTAssertEqual(TimeInterval(-(TimeInterval.hour + TimeInterval.minute * 59)).sessionLengthText, "1 hr 59 min")
        XCTAssertEqual(TimeInterval(-(TimeInterval.hour + TimeInterval.minute * 59 + 25)).sessionLengthText, "1 hr 59 min")

        XCTAssertEqual(TimeInterval(-(TimeInterval.day)).sessionLengthText, "1 day")
        XCTAssertEqual(TimeInterval(-(TimeInterval.day + TimeInterval.hour)).sessionLengthText, "1 day 1 hr")
        XCTAssertEqual(TimeInterval(-(TimeInterval.day + TimeInterval.hour * 23)).sessionLengthText, "1 day 23 hr")
        XCTAssertEqual(TimeInterval(-(TimeInterval.day + TimeInterval.hour * 23 + 55)).sessionLengthText, "1 day 23 hr")
        XCTAssertEqual(TimeInterval(-(TimeInterval.day * 2)).sessionLengthText, "2 days")
        XCTAssertEqual(TimeInterval(-(TimeInterval.day * 381 + TimeInterval.hour * 16)).sessionLengthText, "381 days 16 hr")
    }

}
