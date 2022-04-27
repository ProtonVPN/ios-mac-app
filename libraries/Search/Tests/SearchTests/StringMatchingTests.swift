//
//  Created on 14.03.2022.
//
//  Copyright (c) 2022 Proton AG
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
@testable import Search

final class StringMatchingTests: XCTestCase {
    func testMatchingInSingleWords() {
        let name = "France"
        let ranges = name.findStartingRanges(of: "Fr")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first, NSRange(location: 0, length: 2))
    }

    func testNotMatchingInSingleWords() {
        let name = "France"
        let ranges = name.findStartingRanges(of: "nce")
        XCTAssertEqual(ranges.count, 0)
    }

    func testMatchingInMultipleWords() {
        let name = "United States"
        let ranges = name.findStartingRanges(of: "Unit")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first, NSRange(location: 0, length: 4))
    }

    func testMatchingInMultipleWordsSecondWord() {
        let name = "United States"
        let ranges = name.findStartingRanges(of: "sta")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first, NSRange(location: 7, length: 3))
    }

    func testMatchingInMultipleWordsMultipleTimes() {
        let name = "United Unites"
        let ranges = name.findStartingRanges(of: "Unit")
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first, NSRange(location: 0, length: 4))
        XCTAssertEqual(ranges.last, NSRange(location: 7, length: 4))
    }

    func testNotMatchingInMultipleWords() {
        let name = "United States"
        let ranges = name.findStartingRanges(of: "e")
        XCTAssertEqual(ranges.count, 0)
    }

    func testMatchingInMultipleWordsWithASpace() {
        let name = "United States"
        let ranges = name.findStartingRanges(of: "Unit ")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first, NSRange(location: 0, length: 4))
    }

    func testMatchingInMultipleWordsFully() {
        let name = "United States"
        let ranges = name.findStartingRanges(of: "United Sta")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first, NSRange(location: 0, length: 10))
    }
}
