//
//  Created on 02/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation
import XCTest

import Ergonomics

final class DateFormatterTests: XCTestCase {

    struct DateTestCase {
        let timestamp: TimeInterval
        let imfString: String
        let description: String
    }

    public let cases: [DateTestCase] = [
        .init(timestamp: 0, imfString: "Thu, 01 Jan 1970 00:00:00 GMT", description: "Unix epoch"),
        .init(timestamp: 1712057924, imfString: "Tue, 02 Apr 2024 11:38:44 GMT", description: "AM"),
        .init(timestamp: 1712073621, imfString: "Tue, 02 Apr 2024 16:00:21 GMT", description: "PM"),
    ]

    func testConvertsStringToDate() throws {
        try cases.forEach { testCase in
            let result = DateFormatter.imf.date(from: testCase.imfString)
            let date = try XCTUnwrap(result)
            XCTAssertEqual(date.timeIntervalSince1970, testCase.timestamp, testCase.description)
        }
    }

    func testReturnsStringWithCorrectFormat() throws {
        cases.forEach { testCase in
            let date = Date(timeIntervalSince1970: testCase.timestamp)
            let formattedString = DateFormatter.imf.string(from: date)
            XCTAssertEqual(formattedString, testCase.imfString, testCase.description)
        }
    }
}
