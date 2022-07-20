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
import XCTest
import NetworkExtension

@testable import vpncore

class VpnManagerTests: BaseConnectionTestCase {
    override func setUp() {
        super.setUp()

        // I have no idea why this is here. But we set it so that onDemand gets set to true
        // in the IKEv2 tests. Why onDemand should be set to false in the first IKEv2 connection
        // is currently beyond my understanding.
        container.propertiesManager.hasConnected = true
    }

    func testRotatingConnectionsBetweenWireguardOpenVpnAndIke() {
        let expectations = (
            vpnManagerWireguardConnect: XCTestExpectation(description: "vpn manager wireguard connect"),
            wireguardTunnelStarted: XCTestExpectation(description: "wireguard tunnel started"),
            wireguardConnectedDate: XCTestExpectation(description: "wireguard connected date"),
            wireguardOnDemandEnabled: XCTestExpectation(description: "wireguard on demand enabled"),
            openVpnTunnelStarted: XCTestExpectation(description: "openvpn tunnel started"),
            vpnManagerOpenVpnConnect: XCTestExpectation(description: "vpn manager openvpn connect"),
            openVpnConnectedDate: XCTestExpectation(description: "openvpn connected date"),
            openVpnOnDemandEnabled: XCTestExpectation(description: "openvpn on demand enabled"),
            ikeTunnelStarted: XCTestExpectation(description: "ike tunnel started"),
            vpnManagerIkeConnect: XCTestExpectation(description: "vpn manager ike connect"),
            ikeConnectedDate: XCTestExpectation(description: "ike connected date"),
            ikeOnDemandEnabled: XCTestExpectation(description: "ike on demand enabled"),
            ikeDisconnected: XCTestExpectation(description: "ike disconnected"),
            disconnectedNilConnectedDate: XCTestExpectation(description: "disconnected calling connected date"),
            disconnectedOnDemandDisabled: XCTestExpectation(description: "on demand disabled after disconnect"),
            removedFromPreferences: XCTestExpectation(description: "remove configurations from prefs")
        )

        let wgConfig = VpnManagerConfiguration(hostname: "wireguard.protonvpn.ch",
                                               serverId: "abcde",
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
                                               serverPublicKey: "serverPublicKey")

        var dateConnectionEstablished: Date? = nil

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
            XCTAssertEqual(providerProtocol.providerConfiguration?["wg-protocol"] as? String, "udp")
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

        wait(for: [expectations.wireguardTunnelStarted,
                   expectations.vpnManagerWireguardConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.udp))
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)
        XCTAssertEqual(container.vpnManager.state, .connected(.init(username: "", address: "127.0.0.1")))
        container.vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.wireguardConnectedDate.fulfill()
        })

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(enabled, "On demand should be enabled for wireguard")
            expectations.wireguardOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.wireguardConnectedDate,
                   expectations.wireguardOnDemandEnabled], timeout: expectationTimeout)

        container.propertiesManager.killSwitch = !container.propertiesManager.killSwitch

        let ovpnConfig = VpnManagerConfiguration(hostname: "openvpn.protonvpn.ch",
                                                 serverId: "fghij",
                                                 entryServerAddress: "127.0.0.3",
                                                 exitServerAddress: "127.0.0.4",
                                                 username: "openVpnUser",
                                                 password: "openVpnPassword",
                                                 passwordReference: Data(),
                                                 clientPrivateKey: "",
                                                 vpnProtocol: .openVpn(.tcp),
                                                 netShield: .level2,
                                                 vpnAccelerator: true,
                                                 bouncing: "0",
                                                 natType: .strictNAT,
                                                 safeMode: false,
                                                 ports: [15410],
                                                 serverPublicKey: "")

        dateConnectionEstablished = nil
        var didDisconnectWireGuard = false

        statusChanged = { status in
            guard status == .connected else {
                if status == .disconnected {
                    didDisconnectWireGuard = true
                }
                return
            }

            guard let tunnelManager = tunnelManager else {
                XCTFail("No tunnelManager created yet")
                return
            }

            XCTAssert(didDisconnectWireGuard, "Should have disconnected from wireguard first!")

            guard let providerProtocol = tunnelManager.protocolConfiguration as? NETunnelProviderProtocol else {
                XCTFail("Manager is connecting to something that does not use NETunnelProviderProtocol, definitely not OpenVpn!")
                return
            }

            XCTAssertEqual(tunnelManager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(tunnelManager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(tunnelManager.isEnabled, "OpenVpn manager should be enabled")
            XCTAssert(tunnelManager.isOnDemandEnabled, "OpenVpn on demand rules should be enabled")

            XCTAssertEqual(providerProtocol.providerBundleIdentifier, MockDependencyContainer.openvpnProviderBundleId)
            XCTAssertEqual(providerProtocol.providerConfiguration?["appGroup"] as? String, MockDependencyContainer.appGroup)

            let sessionConfig = providerProtocol.providerConfiguration?["sessionConfiguration"] as? [String: Any]
            XCTAssertNotNil(sessionConfig)
            XCTAssertEqual(sessionConfig?["hostname"] as? String, "127.0.0.3")
            XCTAssertEqual(providerProtocol.serverAddress, ovpnConfig.entryServerAddress)

            if #available(iOS 14.2, *) {
                XCTAssertEqual(providerProtocol.includeAllNetworks, self.container.propertiesManager.killSwitch)
                XCTAssertEqual(providerProtocol.excludeLocalNetworks, self.container.propertiesManager.excludeLocalNetworks)
            }

            XCTAssertNotNil(connection, "Connection should exist")
            XCTAssertNotNil(connection?.connectedDate, "Connection date should exist")
            dateConnectionEstablished = connection?.connectedDate
            expectations.openVpnTunnelStarted.fulfill()
        }

        self.container.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: ovpnConfig) {
            expectations.vpnManagerOpenVpnConnect.fulfill()
        }

        wait(for: [expectations.openVpnTunnelStarted, expectations.vpnManagerOpenVpnConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .openVpn(.tcp))
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)
        XCTAssertEqual(container.vpnManager.state, .connected(.init(username: "openVpnUser", address: "127.0.0.3")))
        container.vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.openVpnConnectedDate.fulfill()
        })

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(enabled, "On demand should be enabled for openvpn")
            expectations.openVpnOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.openVpnConnectedDate,
                   expectations.openVpnOnDemandEnabled], timeout: expectationTimeout)

        dateConnectionEstablished = nil
        var didDisconnectOpenVpn = false

        // XXX: need to fix IKEv2 configuration bug with kill switch: gets the setting
        // from preferences instead of observing the configuration of the vpn configuration object
        container.propertiesManager.killSwitch = !container.propertiesManager.killSwitch

        let ikeConfig = VpnManagerConfiguration(hostname: "ike.protonvpn.ch",
                                                serverId: "klmnop",
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
                                                serverPublicKey: "")

        statusChanged = { status in
            guard status == .connected else {
                if status == .disconnected {
                    didDisconnectOpenVpn = true
                }
                return
            }

            let manager = self.container.neVpnManager

            XCTAssert(didDisconnectOpenVpn, "Should have disconnected from openvpn first!")

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

        wait(for: [expectations.ikeTunnelStarted, expectations.vpnManagerIkeConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .ike)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)
        XCTAssertEqual(container.vpnManager.state, .connected(.init(username: "", address: "127.0.0.5")))
        container.vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.ikeConnectedDate.fulfill()
        })

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(self.container.propertiesManager.hasConnected)
            XCTAssertEqual(enabled, self.container.propertiesManager.hasConnected, "On demand should be enabled for ike")
            expectations.ikeOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.ikeConnectedDate,
                   expectations.ikeOnDemandEnabled], timeout: expectationTimeout)

        container.vpnManager.disconnect {
            expectations.ikeDisconnected.fulfill()
        }

        wait(for: [expectations.ikeDisconnected], timeout: expectationTimeout)
        XCTAssertEqual(container.vpnManager.state, .disconnected)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)

        container.vpnManager.connectedDate { nilDate in
            XCTAssertNil(nilDate)
            expectations.disconnectedNilConnectedDate.fulfill()
        }

        container.vpnManager.isOnDemandEnabled { enabled in
            XCTAssertFalse(enabled, "On demand should be disabled after disconnect")
            expectations.disconnectedOnDemandDisabled.fulfill()
        }

        wait(for: [expectations.disconnectedNilConnectedDate,
                   expectations.disconnectedOnDemandDisabled], timeout: expectationTimeout)

        XCTAssertNotNil(NEVPNManagerMock.whatIsSavedToPreferences)
        XCTAssertFalse(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)

        container.vpnManager.removeConfigurations { error in
            XCTAssertNil(error, "Should not receive error removing configurations")
            expectations.removedFromPreferences.fulfill()
        }

        wait(for: [expectations.removedFromPreferences], timeout: expectationTimeout)

        XCTAssertNil(NEVPNManagerMock.whatIsSavedToPreferences, "should have removed config from preferences")
        XCTAssert(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssert(container.neTunnelProviderFactory.tunnelProviderPreferencesData.isEmpty)
    }
}
