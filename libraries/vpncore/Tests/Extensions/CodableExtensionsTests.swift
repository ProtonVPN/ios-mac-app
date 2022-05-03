//
//  Created on 03.05.2022.
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

import Foundation
import XCTest
@testable import vpncore

class CodableExtennsionsTests: XCTestCase {
    func testDecodingDefaultBoolValue() {
        let json = """
        {
            "a": true,
            "b": true,
            "c": false
        }
        """

        let data = try! JSONDecoder().decode(TestStruct.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(data.a)
        XCTAssertTrue(data.b)
        XCTAssertFalse(data.c)
    }

    func testDecodingDefaultMissingBoolValue() {
        let json = """
        {
            "a": true,
            "c": false
        }
        """

        let data = try! JSONDecoder().decode(TestStruct.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(data.a)
        XCTAssertFalse(data.b)
        XCTAssertFalse(data.c)
    }

    func testEncodingDefaultBoolValue() {
        let data = TestStruct(a: true, b: true, c: false)
        let encoded = try! JSONEncoder().encode(data)
        let json = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(json, "{\"a\":true,\"b\":true,\"c\":false}")
    }
}

struct TestStruct: Codable {
    let a: Bool
    @Default<Bool> var b: Bool
    let c: Bool
}
