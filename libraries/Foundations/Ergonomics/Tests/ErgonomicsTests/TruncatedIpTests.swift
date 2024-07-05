//
//  Created on 05/07/2024.
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

final class TruncatedIpTests: XCTestCase {
    func testTruncatesIPv4() {
        XCTAssertEqual(TruncatedIp(ip: "213.153.191.49")?.value, "213.153.191.0")
    }
    
    func testTruncatesIPv6() {
        XCTAssertEqual(TruncatedIp(ip: "2001:0000:130F:0000:0000:09C0:876A:130B")?.value, "2001:0000:130F:0000:0000:09C0:876A::")
    }

    func testReturnsNilForInvalidIP() {
        XCTAssertNil(TruncatedIp(ip: "hello")?.value)
    }
}
