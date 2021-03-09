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
    private let delay: UInt32 = 2
    private var servers: [NetworkServer] = []
    private let config = OpenVpnConfig(defaultTcpPorts: [], defaultUdpPorts: [10011])

    override func tearDown() {
        servers.forEach {
            $0.stop()
        }
        servers.removeAll()
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
        let sp = OpenVPNUDPAvailabilityChecker(queue: .global(qos: .utility), config: self.config)

        group.notify(queue: .main) {
            sp.checkAvailability(server: ServerModel(domain: "localhost")) { result in
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
        let sp = OpenVPNUDPAvailabilityChecker(queue: .global(qos: .utility), config: config)
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
        sleep(delay)

        let expectation = XCTestExpectation(description: "testUDPListeningButNotResponding")

        group.notify(queue: .main) {
            let sp = OpenVPNUDPAvailabilityChecker(queue: .global(qos: .utility), config: self.config)
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
