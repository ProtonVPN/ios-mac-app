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
@testable import LegacyCommon

class CodableExtennsionsTests: XCTestCase {
    func testDecodingDefaultBoolValue() {
        do {
            let json = """
            {
                "a": true,
                "b": true,
                "c": false,
                "d": false,
            }
            """

            let data = try! JSONDecoder().decode(TestStruct.self, from: json.data(using: .utf8)!)
            XCTAssertTrue(data.a)
            XCTAssertTrue(data.b)
            XCTAssertFalse(data.c)
            XCTAssertFalse(data.d)
        }

        do {
            let json = """
            {
                "a": true,
                "b": false,
                "c": false,
                "d": true,
            }
            """

            let data = try! JSONDecoder().decode(TestStruct.self, from: json.data(using: .utf8)!)
            XCTAssertTrue(data.a)
            XCTAssertFalse(data.b)
            XCTAssertFalse(data.c)
            XCTAssertTrue(data.d)
        }
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
        XCTAssertTrue(data.d)
    }

    func testEncodingDefaultBoolValue() {
        do {
            let data = TestStruct(a: true, b: true, c: false, d: true)
            let encoded = try! JSONEncoder().encode(data)
            guard let json = String(data: encoded, encoding: .utf8) else {
                XCTFail("String encoding error")
                return
            }

            XCTAssert(json.contains("\"a\":true"))
            XCTAssert(json.contains("\"b\":true"))
            XCTAssert(json.contains("\"c\":false"))
            XCTAssert(json.contains("\"d\":true"))
        }

        do {
            let data = TestStruct(a: true, b: false, c: false, d: false)
            let encoded = try! JSONEncoder().encode(data)
            guard let json = String(data: encoded, encoding: .utf8) else {
                XCTFail("String encoding error")
                return
            }

            XCTAssert(json.contains("\"a\":true"))
            XCTAssert(json.contains("\"b\":false"))
            XCTAssert(json.contains("\"c\":false"))
            XCTAssert(json.contains("\"d\":false"))
        }
    }
}

struct TestStruct: Codable {
    let a: Bool
    @Default<Bool> var b: Bool
    let c: Bool
    @Default<BoolDefaultTrue> var d: Bool
}
