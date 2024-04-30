//
//  Created on 2022-06-16.
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
import NetworkExtension
import XCTest

import Domain
import VPNShared

@testable import LegacyCommon

class VpnManagerTests: BaseConnectionTestCase {
    override func setUp() {
        super.setUp()

        // I have no idea why this is here. But we set it so that onDemand gets set to true
        // in the IKEv2 tests. Why onDemand should be set to false in the first IKEv2 connection
        // is currently beyond my understanding.
        container.propertiesManager.hasConnected = true
    }

    func testRotatingConnectionsBetweenWireguardOpenVpnAndIke() async throws { // swiftlint:disable:this function_body_length cyclomatic_complexity
        let expectations = (
            vpnManagerWireguardConnect: XCTestExpectation(description: "vpn manager wireguard connect"),
            wireguardTunnelStarted: XCTestExpectation(description: "wireguard tunnel started"),
            wireguardOnDemandEnabled: XCTestExpectation(description: "wireguard on demand enabled"),
            vpnManagerOpenVpnConnect: XCTestExpectation(description: "vpn manager openvpn connect"),
            ikeTunnelStarted: XCTestExpectation(description: "ike tunnel started"),
            vpnManagerIkeConnect: XCTestExpectation(description: "vpn manager ike connect"),
            ikeOnDemandEnabled: XCTestExpectation(description: "ike on demand enabled"),
            ikeDisconnected: XCTestExpectation(description: "ike disconnected"),
            disconnectedOnDemandDisabled: XCTestExpectation(description: "on demand disabled after disconnect"),
            removedFromPreferences: XCTestExpectation(description: "remove configurations from prefs")
        )

        let wgConfig = VpnManagerConfiguration(
            id: UUID(),
            hostname: "wireguard.protonvpn.ch",
            serverId: "abcde",
            ipId: "fghij",
            entryServerAddress: "127.0.0.1",
            exitServerAddress: "127.0.0.2",
            username: "",
            password: "",
            passwordReference: Data(),
            clientPrivateKey: "clientPrivateKey",
            vpnProtocol: .wireGuard(.udp),
            netShield: .level1,
            vpnAccelerator: true,
            bouncing: "0",
            natType: .moderateNAT,
            safeMode: true,
            ports: [15213],
            serverPublicKey: "serverPublicKey",
            intent: .fastest
        )

        var dateConnectionEstablished: Date?

        var connection: NEVPNConnectionMock?
        var tunnelManager: NETunnelProviderManagerMock?

        tunnelManagerCreated = { manager in
            tunnelManager = manager
        }

        tunnelConnectionCreated = { vpnConnection in
            connection = vpnConnection
        }

        statusChanged = { status in
            guard status == .connected else {
                return
            }

            guard let tunnelManager = tunnelManager else {
                XCTFail("No tunnelManager created yet")
                return
            }

            guard let providerProtocol = tunnelManager.protocolConfiguration as? NETunnelProviderProtocol else {
                XCTFail("Manager is connecting to something that does not use NETunnelProviderProtocol, definitely not WireGuard!")
                return
            }

            XCTAssertEqual(tunnelManager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(tunnelManager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(tunnelManager.isEnabled, "OpenVpn manager should be enabled")
            XCTAssert(tunnelManager.isOnDemandEnabled, "OpenVpn on demand rules should be enabled")

            XCTAssertEqual(providerProtocol.providerBundleIdentifier, MockDependencyContainer.wireguardProviderBundleId)
            XCTAssertEqual(providerProtocol.wgProtocol, "udp")
            XCTAssertEqual(providerProtocol.serverAddress, wgConfig.entryServerAddress)

            if #available(iOS 14.2, *) {
                XCTAssertEqual(providerProtocol.includeAllNetworks, self.container.propertiesManager.killSwitch)
                XCTAssertEqual(providerProtocol.excludeLocalNetworks, self.container.propertiesManager.excludeLocalNetworks)
            }

            XCTAssertNotNil(connection)
            XCTAssertNotNil(connection?.connectedDate)
            dateConnectionEstablished = connection?.connectedDate
            expectations.wireguardTunnelStarted.fulfill()
        }

        container.vpnManager.whenReady(queue: .main) {
            self.container.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: wgConfig) {
                expectations.vpnManagerWireguardConnect.fulfill()
            }
        }

        await fulfillment(
            of: [expectations.wireguardTunnelStarted,
            expectations.vpnManagerWireguardConnect], timeout: expectationTimeout
        )

        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.udp))
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)
        XCTAssertEqual(container.vpnManager.state, .connected(.init(username: "", address: "127.0.0.1")))

        var connectedDate = await container.vpnManager.connectedDate()
        var date = try XCTUnwrap(connectedDate)
        XCTAssertEqual(date, dateConnectionEstablished)

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(enabled, "On demand should be enabled for wireguard")
            expectations.wireguardOnDemandEnabled.fulfill()
        }

        await fulfillment(of: [expectations.wireguardOnDemandEnabled], timeout: expectationTimeout)

        #if os(iOS)
        throw XCTSkip("IKE is not supported on iOS")
        #endif

        container.propertiesManager.killSwitch = !container.propertiesManager.killSwitch

        dateConnectionEstablished = nil
        var didDisconnectWireGuard = false

        // XXX: need to fix IKEv2 configuration bug with kill switch: gets the setting
        // from preferences instead of observing the configuration of the vpn configuration object
        container.propertiesManager.killSwitch = !container.propertiesManager.killSwitch

        let ikeConfig = VpnManagerConfiguration(
            id: UUID(),
            hostname: "ike.protonvpn.ch",
            serverId: "klmnop",
            ipId: "fghij",
            entryServerAddress: "127.0.0.5",
            exitServerAddress: "127.0.0.6",
            username: "ikeUser",
            password: "ikePassword",
            passwordReference: Data(),
            clientPrivateKey: "",
            vpnProtocol: .ike,
            netShield: .off,
            vpnAccelerator: true,
            bouncing: "0",
            natType: .moderateNAT,
            safeMode: true,
            ports: [15112],
            serverPublicKey: "",
            intent: .fastest
        )

        statusChanged = { status in
            guard status == .connected else {
                if status == .disconnected {
                    didDisconnectWireGuard = true
                }
                return
            }

            let manager = self.container.neVpnManager

            XCTAssert(didDisconnectWireGuard, "Should have disconnected from wireguard first!")

            let protocolConfig = manager.protocolConfiguration
            XCTAssert(protocolConfig is NEVPNProtocolIKEv2, "Protocol configuration should be for IKEv2")

            XCTAssertFalse(manager is NETunnelProviderManagerMock, "Should be base class for IKEv2")
            XCTAssertEqual(manager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(manager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(manager.isEnabled, "IKEv2 manager should be enabled")

            XCTAssert(self.container.propertiesManager.hasConnected)
            XCTAssert(manager.isOnDemandEnabled, "IKEv2 on demand rules should be enabled")

            XCTAssertNil(protocolConfig?.username)
            XCTAssertNil(protocolConfig?.passwordReference)
            XCTAssertEqual(protocolConfig?.serverAddress, ikeConfig.entryServerAddress)
            if #available(iOS 14.2, *) {
                XCTAssertEqual(protocolConfig?.includeAllNetworks, self.container.propertiesManager.killSwitch)
                XCTAssertEqual(protocolConfig?.excludeLocalNetworks, self.container.propertiesManager.excludeLocalNetworks)
            }

            dateConnectionEstablished = manager.vpnConnection.connectedDate
            expectations.ikeTunnelStarted.fulfill()
        }

        self.container.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: ikeConfig) {
            expectations.vpnManagerIkeConnect.fulfill()
        }

        await fulfillment(of: [expectations.ikeTunnelStarted, expectations.vpnManagerIkeConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .ike)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)
        XCTAssertEqual(container.vpnManager.state, .connected(.init(username: "", address: "127.0.0.5")))
        connectedDate = await container.vpnManager.connectedDate()
        date = try XCTUnwrap(connectedDate)
        XCTAssertNotNil(date)
        XCTAssertEqual(date, dateConnectionEstablished)

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(self.container.propertiesManager.hasConnected)
            XCTAssertEqual(enabled, self.container.propertiesManager.hasConnected, "On demand should be enabled for ike")
            expectations.ikeOnDemandEnabled.fulfill()
        }

        await fulfillment(of: [expectations.ikeOnDemandEnabled], timeout: expectationTimeout)

        container.vpnManager.disconnect {
            expectations.ikeDisconnected.fulfill()
        }

        await fulfillment(of: [expectations.ikeDisconnected], timeout: expectationTimeout)
        XCTAssertEqual(container.vpnManager.state, .disconnected)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)

        let nilDate = await container.vpnManager.connectedDate()
        XCTAssertNil(nilDate)

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssertFalse(enabled, "On demand should be disabled after disconnect")
            expectations.disconnectedOnDemandDisabled.fulfill()
        }

        await fulfillment(of: [expectations.disconnectedOnDemandDisabled], timeout: expectationTimeout)

        XCTAssertNotNil(NEVPNManagerMock.whatIsSavedToPreferences)
        XCTAssertFalse(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)

        container.vpnManager.removeConfigurations { error in
            XCTAssertNil(error, "Should not receive error removing configurations")
            expectations.removedFromPreferences.fulfill()
        }

        await fulfillment(of: [expectations.removedFromPreferences], timeout: expectationTimeout)

        XCTAssertNil(NEVPNManagerMock.whatIsSavedToPreferences, "should have removed config from preferences")
        XCTAssert(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssert(container.neTunnelProviderFactory.tunnelProviderPreferencesData.isEmpty)
    }
}
