//
//  SmartProtocolImplementationTests.swift
//  vpncore - Created on 08.03.2021.
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

final class SmartProtocolImplementationTests: XCTestCase {
    private var servers: [NetworkServer] = []
    private let config = OpenVpnConfig(defaultTcpPorts: [10001], defaultUdpPorts: [10023])

    override func tearDown() {
        servers.forEach {
            $0.stop()
        }
        servers.removeAll()
    }

    func testSmartProtocolWhenOnlyOpenVPNTCPAvailable() {
        let group = DispatchGroup()
        servers = config.defaultUdpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .udp, responseCondition: { _ in false })
        } + config.defaultTcpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { _ in true })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "Smart protocol")
        let sp = SmartProtocolImplementation(config: config)
        group.notify(queue: .main) {
            sp.determineBestProtocol(server: ServerModelMock(domain: "localhost")) { (proto, ports) in
                XCTAssertEqual(proto, VpnProtocol.openVpn(.tcp))
                XCTAssertEqual(ports.sorted(), self.config.defaultTcpPorts.sorted())
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }

    func testSmartProtocolWhenOnlyOpenVPNTCPAndUDPAvailable() {
        let group = DispatchGroup()
        servers = config.defaultUdpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .udp, responseCondition: { _ in true })
        } + config.defaultTcpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { _ in true })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "Smart protocol")
        let sp = SmartProtocolImplementation(config: config)
        group.notify(queue: .main) {
            sp.determineBestProtocol(server: ServerModelMock(domain: "localhost")) { (proto, ports) in
                XCTAssertEqual(proto, VpnProtocol.openVpn(.udp))
                XCTAssertEqual(ports.sorted(), self.config.defaultUdpPorts.sorted())
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }

    func testSmartProtocolWhenNothingAvailable() {
        let group = DispatchGroup()
        servers = config.defaultUdpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .udp, responseCondition: { _ in false })
        } + config.defaultTcpPorts.map {
            NetworkServer(port: UInt16($0), parameters: .tcp, responseCondition: { _ in false })
        }
        servers.forEach {
            group.enter()
            $0.ready = {
                group.leave()
            }
            try! $0.start()
        }

        let expectation = XCTestExpectation(description: "Smart protocol")
        let sp = SmartProtocolImplementation(config: config)
        group.notify(queue: .main) {
            sp.determineBestProtocol(server: ServerModelMock(domain: "localhost")) { (proto, ports) in
                XCTAssertEqual(proto, VpnProtocol.ike)
                XCTAssertEqual(ports, [])
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
    }
}
