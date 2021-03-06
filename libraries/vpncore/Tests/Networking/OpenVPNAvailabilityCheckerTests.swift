//
//  OpenVPNAvailabilityCheckerTests.swift
//  vpncore - Created on 06.03.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import vpncore
import XCTest


final class OpenVPNAvailabilityCheckerTests: XCTestCase {
    func testUDPCapableServer() {
        let expectation = XCTestExpectation(description: "UDP available")
        let sp = OpenVPNAvailabilityChecker()
        sp.checkAvailability(server: ServerModel(domain: "nl-134.protonvpn.com"), procotocol: .udp) { result in
            XCTAssertTrue(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testTCPCapableServer() {
        let expectation = XCTestExpectation(description: "TCP available")
        let sp = OpenVPNAvailabilityChecker()
        sp.checkAvailability(server: ServerModel(domain: "nl-134.protonvpn.com"), procotocol: .tcp) { result in
            XCTAssertTrue(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }
}
