//
//  Created on 2022-11-22.
//
//  Copyright (c) 2022 Proton AG
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
import NetworkExtension
import VPNShared
@testable import vpncore

/// - Note: To be implemented with remainder of protocol overrides feature.
class ProtocolOverrideConnectionTests: ConnectionTestCaseDriver {
    override func setUp() {
        super.setUp()

        let testData = MockTestData()

        container.networkingDelegate.apiServerList = [
            testData.server1, testData.server3, testData.server4,
            testData.server5, testData.server6, testData.server8,
        ]
    }

    func testConnectingWithIpOverride() {
        container.propertiesManager.vpnProtocol = .ike

        populateExpectations(description: "Should be normal non-overridden server IP for IKE protocol",
                             [.vpnConnection])
        container.vpnGateway.connectTo(server: testData.server4)
        awaitExpectations()

        let ikeConfig = container.neVpnManager.protocolConfiguration
        XCTAssertEqual(ikeConfig?.serverAddress, testData.server4.ips.first?.entryIp)

        populateExpectations(description: "Should be overridden server IP for stealth protocol",
                             [.vpnDisconnection, .vpnConnection, .certificateRefresh, .localAgentConnection])
        container.vpnGateway.disconnect()

        container.propertiesManager.vpnProtocol = .wireGuard(.tls)
        container.vpnGateway.connectTo(server: testData.server4)

        awaitExpectations()

        XCTAssertEqual(manager?.protocolConfiguration?.serverAddress,
                       self.testData.server4.ips.first?.protocolEntries?[.wireGuard(.tls)]??.ipv4)
    }

    func testConnectingWithIpAndPortOverride() {
        var managerConfig: VpnManagerConfiguration?

        populateExpectations(description: "Should be overridden server IP for stealth protocol",
                             [.vpnConnection, .certificateRefresh, .localAgentConnection])

        container.didConfigure = { vmc, _ in
            managerConfig = vmc
        }

        container.propertiesManager.vpnProtocol = .wireGuard(.tls)
        container.vpnGateway.connectTo(server: testData.server5)

        awaitExpectations()

        guard let serverAddress = manager?.protocolConfiguration?.serverAddress else {
            XCTFail("No server address was available in the protocol configuration.")
            return
        }

        guard let override = testData.server5.ips.first?.protocolEntries?[.wireGuard(.tls)],
              let override,
              let ports = override.ports,
              let port = ports.first else {
            XCTFail("Unreachable")
            return
        }

        XCTAssertEqual(serverAddress, override.ipv4)

        guard let managerConfig else {
            XCTFail("WireGuard manager config not stored after connection")
            return
        }

        XCTAssertEqual(managerConfig.ports.count, 1)
        XCTAssertEqual(managerConfig.ports.first, port)
        XCTAssertEqual(managerConfig.entryServerAddress, serverAddress)
    }

    func testExclusiveOverrideWithNoSpecifiedPort() {
        var managerConfig: VpnManagerConfiguration?

        populateExpectations(description: "Should be entry IP specified on server 6",
                             [.vpnConnection, .certificateRefresh, .localAgentConnection])

        container.didConfigure = { vmc, _ in
            managerConfig = vmc
        }

        container.propertiesManager.vpnProtocol = .wireGuard(.tls)
        container.vpnGateway.connectTo(server: testData.server6)

        awaitExpectations()

        guard let serverAddress = manager?.protocolConfiguration?.serverAddress else {
            XCTFail("No server address was available in the protocol configuration.")
            return
        }

        XCTAssertEqual(serverAddress, testData.server6.ips.first?.entryIp)

        guard let managerConfig else {
            XCTFail("WireGuard manager config not stored after connection")
            return
        }

        XCTAssertEqual(managerConfig.entryServerAddress, serverAddress)
    }

    func testExclusiveOverrideWithSpecifiedPorts() {
        var managerConfig: VpnManagerConfiguration?

        populateExpectations(description: "Should connect to openvpn, with overridden ports", [.vpnConnection])

        container.didConfigure = { vmc, _ in
            managerConfig = vmc
        }

        container.propertiesManager.vpnProtocol = .openVpn(.udp)
        container.vpnGateway.connectTo(server: testData.server8)

        awaitExpectations()

        guard let serverAddress = manager?.protocolConfiguration?.serverAddress else {
            XCTFail("No server address was available in the protocol configuration.")
            return
        }

        guard let override = testData.server8.ips.first?.protocolEntries?[.openVpn(.udp)],
              let override,
              let ports = override.ports else {
            XCTFail("Unreachable")
            return
        }

        XCTAssertEqual(serverAddress, testData.server8.ips.first?.entryIp)

        guard let managerConfig else {
            XCTFail("WireGuard manager config not stored after connection")
            return
        }

        XCTAssertEqual(managerConfig.ports.count, 2)
        XCTAssert(!Set(ports).isDisjoint(with: managerConfig.ports))
        XCTAssertEqual(managerConfig.entryServerAddress, serverAddress)
    }

    func testExclusiveOverrideWithSmartProtocol() {
        var managerConfig: VpnManagerConfiguration?
        // should ignore whatever protocol is set if smart protocol is set to true
        container.propertiesManager.vpnProtocol = .openVpn(.udp)
        container.propertiesManager.smartProtocol = true

        populateExpectations(description: "Should be overridden server IP for stealth protocol",
                             [.vpnConnection, .certificateRefresh, .localAgentConnection])

        container.didConfigure = { vmc, _ in
            managerConfig = vmc
        }

        container.vpnGateway.connectTo(server: testData.server8)

        awaitExpectations()

        guard let serverAddress = manager?.protocolConfiguration?.serverAddress else {
            XCTFail("No server address was available in the protocol configuration.")
            return
        }

        guard let override = testData.server8.ips.first?.protocolEntries?[.wireGuard(.udp)],
              let override else {
            XCTFail("Unreachable")
            return
        }

        XCTAssertEqual(serverAddress, override.ipv4)

        guard let managerConfig else {
            XCTFail("WireGuard manager config not stored after connection")
            return
        }

        let defaultPorts = container.availabilityCheckerResolverFactory
            .checkers[.wireGuard(.udp)]?.defaultPorts ?? []
        XCTAssert(!Set(managerConfig.ports).isDisjoint(with: defaultPorts))

        XCTAssertEqual(managerConfig.entryServerAddress, serverAddress)
    }

    #if false
    func testExclusiveServerSwitchingDueToMaintenance() {

    }

    func testConnectingToProfileWithOverriddenIP() {

    }

    func testConnectingToProfileWithChangedOverride() {

    }
    #endif
}
