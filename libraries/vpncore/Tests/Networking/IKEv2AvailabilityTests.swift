//
//  SmartProtocolTests.swift
//  vpncore - Created on 05.03.2021.
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

final class IKEv2AvailabilityTests: XCTestCase {
    func testIKEv2CapableServer() {
        let expectation = XCTestExpectation(description: "IKEv2 available")
        let sp = IKEv2AvailabilityChecker(queue: .global(qos: .utility))
        sp.checkAvailability(server: ServerModel(domain: "ch-05.protonvpn.com")) { result in
            switch result {
            case let .available(ports: ports):
                XCTAssertEqual(ports, [500])
            case .unavailable:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testIKEv2IncapableServer() {
        let expectation = XCTestExpectation(description: "IKEv2 unavailable")
        let sp = IKEv2AvailabilityChecker(queue: .global(qos: .utility))
        sp.checkAvailability(server: ServerModel(domain: "uk-12.protonvpn.com")) { result in
            switch result {
            case let .available:
                XCTFail()
            case .unavailable:
                break
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testIKEv2NonExistentServer() {
        let expectation = XCTestExpectation(description: "IKEv2 unavailable")
        let sp = IKEv2AvailabilityChecker(queue: .global(qos: .utility))
        sp.checkAvailability(server: ServerModel(domain: "random.example.com")) { result in
            switch result {
            case let .available:
                XCTFail()
            case .unavailable:
                break
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }
}

extension ServerModel {
    convenience init(domain: String) {
        self.init(id: "id", name: domain, domain: domain, load: 5, entryCountryCode: "", exitCountryCode: "", tier: 0, feature: .zero, city: nil, ips: [], score: 0, status: 0, location: ServerLocation(lat: 0, long: 0))
    }
}
