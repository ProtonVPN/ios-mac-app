//
//  OpenVPNUDPAvailabilityCheckerTests.swift
//  vpncore - Created on 09.03.2021.
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
import Network

final class OpenVPNUDPAvailabilityCheckerTests: XCTestCase {    
    private var servers: [NetworkServer] = []
    private let config = OpenVpnConfig(defaultTcpPorts: [], defaultUdpPorts: [10011, 10012])

    override func tearDown() {
        servers.forEach {
            $0.stop()
        }
        servers.removeAll()
    }

    func testTestPacket() {
        let sp = OpenVPNUDPAvailabilityChecker(config: self.config)
        let packet = sp.createTestPacket()
        let bytes = packet.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: packet.count))
        }

        // always 86 bytes
        XCTAssertEqual(bytes.count, 86)
        XCTAssertEqual(bytes[0], 56)
        XCTAssertEqual(bytes.suffix(5), [0,0,0,0,0])
    }

    func testUDPOnAllPorts() {
        let group = DispatchGroup()
        servers = config.defaultUdpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .udp, responseCondition: { _ in true })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "testUDPOnAllPorts")
        let sp = OpenVPNUDPAvailabilityChecker(config: config)

        group.notify(queue: .main) {
            sp.checkAvailability(server: ServerModelMock(domain: "localhost")) { result in
                switch result {
                case let .available(ports: ports):
                    XCTAssertEqual(ports.sorted(), self.config.defaultUdpPorts)
                case .unavailable:
                    XCTFail()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }

    func testUDPNotListening() {
        let expectation = XCTestExpectation(description: "testUDPNotListening")
        let sp = OpenVPNUDPAvailabilityChecker(config: config)
        sp.checkAvailability(server: ServerModelMock(domain: "localhost")) { result in
            switch result {
            case .available:
                XCTFail()
            case .unavailable:
                break
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testUDPListeningButNotResponding() {
        let group = DispatchGroup()
        servers = [10001].map {
            NetworkServer(port: UInt16($0), parameters: .udp, responseCondition: { _ in false })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "testUDPListeningButNotResponding")

        group.notify(queue: .main) {
            let sp = OpenVPNUDPAvailabilityChecker(config: self.config)
            sp.checkAvailability(server: ServerModelMock(domain: "localhost")) { result in
                switch result {
                case .available:
                    XCTFail()
                case .unavailable:
                    break
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }
}
