//
//  Created on 28/03/2023.
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
@testable import NetShield

final class NetShieldStatsNumberFormatterTests: XCTestCase {

    var formatter = {
        let formatter = NetShieldStatsNumberFormatter()
        formatter.decimalSeparator = "."
        return formatter
    }()

    func testZero() throws {
        let string = formatter.string(from: 0)
        XCTAssertEqual(string, "0")
    }

    func testNegativeNumber() throws {
        let string = formatter.string(from: -10)
        XCTAssertEqual(string, "10")
    }

    func test999() throws {
        let string = formatter.string(from: 999)
        XCTAssertEqual(string, "999")
    }

    func test1234() throws {
        let string = formatter.string(from: 1_234)
        XCTAssertEqual(string, "1.2 K")
    }

    func test2341234() throws {
        let string = formatter.string(from: 2_341_234)
        XCTAssertEqual(string, "2.3 M")
    }

    func test3452341234() throws {
        let string = formatter.string(from: 3_452_341_234)
        XCTAssertEqual(string, "3.5 G")
    }

    func test53452341234() throws {
        let string = formatter.string(from: 53_452_341_234)
        XCTAssertEqual(string, "53.5 G")
    }

    func test673452341234() throws {
        let string = formatter.string(from: 673_452_341_234)
        XCTAssertEqual(string, "673.5 G")
    }

    func test4563452341234() throws {
        let string = formatter.string(from: 4_563_452_341_234)
        XCTAssertEqual(string, "4.6 T")
    }

    func test5674563452341234() throws {
        let string = formatter.string(from: 5_674_563_452_341_234)
        XCTAssertEqual(string, "5.7 P")
    }

    func test6785674563452341234() throws {
        let string = formatter.string(from: 6_785_674_563_452_341_234)
        XCTAssertEqual(string, "6.8 E")
    }
}
