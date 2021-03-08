//
//  OpenVPNTCPAvailabilityCheckerTests.swift
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

final class OpenVPNTCPAvailabilityCheckerTests: XCTestCase {
    private let delay: UInt32 = 1
    private var servers: [TCPServer] = []
    private let config = OpenVpnConfig(defaultTcpPorts: [10001, 10002, 10003], defaultUdpPorts: [])

    override func tearDown() {
        servers.forEach {
            $0.stop()
        }
        servers.removeAll()
    }

    func testTCPOnAllPorts() {
        servers = config.defaultTcpPorts.map {
            TCPServer(port: UInt16($0), responseCondition: { $0.count == 88 })
        }
        servers.forEach {
            try! $0.start()
        }
        sleep(delay)

        let expectation = XCTestExpectation(description: "testTCPOnAllPorts")
        let sp = OpenVPNTCPAvailabilityChecker(queue: .global(qos: .utility), config: config)
        sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
            switch result {
            case let .available(ports: ports):
                XCTAssertEqual(ports.sorted(), self.config.defaultTcpPorts)
            case .unavailable:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testTCPOnSomePorts() {
        servers = [10001, 10002].map {
            TCPServer(port: UInt16($0), responseCondition: { $0.count == 88 })
        }
        servers.forEach {
            try! $0.start()
        }
        sleep(delay)

        let expectation = XCTestExpectation(description: "testTCPOnSomePorts")
        let sp = OpenVPNTCPAvailabilityChecker(queue: .global(qos: .utility), config: config)
        sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
            switch result {
            case let .available(ports: ports):
                XCTAssertEqual(ports.sorted(), [10001, 10002])
            case .unavailable:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testTCPNotListening() {
        let expectation = XCTestExpectation(description: "testTCPNotListening")
        let sp = OpenVPNTCPAvailabilityChecker(queue: .global(qos: .utility), config: config)
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

    func testTCPListeningButNotResponding() {
        servers = [10001].map {
            TCPServer(port: UInt16($0), responseCondition: { _ in false })
        }
        servers.forEach {
            try! $0.start()
        }
        sleep(delay)

        let expectation = XCTestExpectation(description: "testTCPListeningButNotResponding")
        let sp = OpenVPNTCPAvailabilityChecker(queue: .global(qos: .utility), config: config)
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
