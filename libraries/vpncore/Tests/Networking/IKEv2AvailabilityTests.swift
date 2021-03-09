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
    var server: NetworkServer?

    override func tearDown() {
        server?.stop()
        server = nil
    }

    func testTestPacket() {
        let sp = IKEv2AvailabilityChecker()
        let packet = sp.createTestPacket()
        let bytes = packet.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: packet.count))
        }

        // always 28 bytes
        XCTAssertEqual(bytes.count, 28)
        // first 8 bytes are random, no way to assert
        // 8 zeros next
        XCTAssertEqual(bytes.suffix(from: 8).prefix(8), [0,0,0,0,0,0,0,0])
        // 4 specific bytes
        XCTAssertEqual(bytes.suffix(from: 16).prefix(4), [0x21,0x20,0x22,0x08])
        // finish with 8 zeros
        XCTAssertEqual(bytes.suffix(8), [0,0,0,0,0,0,0,0])
    }

    func testIKEv2CapableServer() {
        let port = 55555
        server = NetworkServer(port: UInt16(port), parameters: .udp, responseCondition: { _ in true })
        try! server?.start()

        let expectation = XCTestExpectation(description: "IKEv2 available")
        let sp = IKEv2AvailabilityChecker(port: port)

        server?.ready = {
            sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
                switch result {
                case let .available(ports: ports):
                    XCTAssertEqual(ports, [port])
                case .unavailable:
                    XCTFail()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }

    func testIKEv2NotListening() {
        let expectation = XCTestExpectation(description: "IKEv2 not listening")
        let sp = IKEv2AvailabilityChecker()
        sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
            switch result {
            case .available:
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
