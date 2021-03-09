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
    private var servers: [NetworkServer] = []
    private let config = OpenVpnConfig(defaultTcpPorts: [10001, 10002, 10003], defaultUdpPorts: [])

    override func tearDown() {
        servers.forEach {
            $0.stop()
        }
        servers.removeAll()
    }

    func testTCPOnAllPorts() {
        let group = DispatchGroup()
        servers = config.defaultTcpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { $0.count == 88 })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "testTCPOnAllPorts")

        group.notify(queue: .main) {
            let sp = OpenVPNTCPAvailabilityChecker(config: self.config)
            sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
                switch result {
                case let .available(ports: ports):
                    XCTAssertEqual(ports.sorted(), self.config.defaultTcpPorts)
                case .unavailable:
                    XCTFail()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 4)
    }

    func testTCPOnSomePorts() {
        let group = DispatchGroup()
        servers = [10001, 10002].map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { $0.count == 88 })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "testTCPOnSomePorts")

        group.notify(queue: .main) {
            let sp = OpenVPNTCPAvailabilityChecker(config: self.config)
            sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
                switch result {
                case let .available(ports: ports):
                    XCTAssertEqual(ports.sorted(), [10001, 10002])
                case .unavailable:
                    XCTFail()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 4)
    }

    func testTCPNotListening() {
        let expectation = XCTestExpectation(description: "testTCPNotListening")
        let sp = OpenVPNTCPAvailabilityChecker(config: config)
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
        let group = DispatchGroup()
        servers = [10001].map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { _ in false })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "testTCPListeningButNotResponding")

        group.notify(queue: .main) {
            let sp = OpenVPNTCPAvailabilityChecker(config: self.config)
            sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
                switch result {
                case .available:
                    XCTFail()
                case .unavailable:
                    break
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 4)
    }
}
