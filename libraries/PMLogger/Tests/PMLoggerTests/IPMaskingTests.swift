//
//  Created on 2023-04-27.
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
import PMLogger

final class IPMaskingTests: XCTestCase {

    func testIPV4MaskingWorks() throws {
        XCTAssertEqual("1.2.3.4".maskIPv4, "1.2.*.*")
        XCTAssertEqual("1.20.3.4".maskIPv4, "1.20.*.*")
        XCTAssertEqual("120.2.3.4".maskIPv4, "120.2.*.*")
        XCTAssertEqual("1.2.99.4".maskIPv4, "1.2.*.*")
        XCTAssertEqual("1.2.3.255".maskIPv4, "1.2.*.*")
        XCTAssertEqual(
            "This is a long and interesting string that contains not only IP address like 1.2.3.255, but some other text and maybe even more IP addresses like these: 127.0.0.1, 10.10.0.1".maskIPv4,
            "This is a long and interesting string that contains not only IP address like 1.2.*.*, but some other text and maybe even more IP addresses like these: 127.0.*.*, 10.10.*.*")

        XCTAssertEqual("Just a string with some numbers like 1 2 3 4".maskIPv4, "Just a string with some numbers like 1 2 3 4")
    }

    func testIPV6MaskingWorks() throws {
        let ipv6Addresses = [
            "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
            "2001:0db8::1",
            "fe80::a00:27ff:fe79:7a08",
            "::1",
            "2001:0:9d38:90d7:64b5:e171:7e89:1b31",
            "2001:0db8:0000:0000:0000:0000:0000:0001",
            "2001:4860:4860::8888",
            "2a02:120b:2c0d:5600:e4d4:2ff:fe01:b9d4",
            "2400:cb00:2048:1::681f:3a6d"
        ]

        for ip in ipv6Addresses {
            XCTAssertEqual(ip.maskIPv6, "ip:v6:removed")
        }

        XCTAssertEqual(
            "This is a long and interesting string that contains not only IP address like \(ipv6Addresses[0]), but some other text and maybe even more IP addresses like these: \(ipv6Addresses[1]), \(ipv6Addresses[2])".maskIPv6,
            "This is a long and interesting string that contains not only IP address like ip:v6:removed, but some other text and maybe even more IP addresses like these: ip:v6:removed, ip:v6:removed")

        XCTAssertEqual("Just a string with some numbers like 1 2 3 4".maskIPv6, "Just a string with some numbers like 1 2 3 4")
    }

    func testIPMaskingWorks() throws {
        XCTAssertEqual("1.2.3.4 and 2a02:120b:2c0d:5600:e4d4:2ff:fe01:b9d4".maskIPs, "1.2.*.* and ip:v6:removed")
    }

}
