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

typealias VpnManagerDependencyFactories = NEVPNManagerWrapperFactory &
                                            NETunnelProviderManagerWrapperFactory &
                                            VpnCredentialsConfiguratorFactory

fileprivate class VpnManagerDependencies {
    static let appGroup = "test"
    static let wireguardProviderBundleId = "ch.protonvpn.test.wireguard"
    static let openvpnProviderBundleId = "ch.protonvpn.test.openvpn"

    var neVpnManagerConnectionStateChangeCallback: ((NEVPNConnectionMock, NEVPNStatus) -> Void)?
    var neVpnManager = NEVPNManagerMock()

    var neTunnelProviderFactory = NETunnelProviderManagerFactoryMock()

    var preferences = PropertiesManagerMock()

    lazy var ikeFactory = IkeProtocolFactory(factory: self)
    lazy var openVpnFactory = OpenVpnProtocolFactory(bundleId: Self.openvpnProviderBundleId,
                                                     appGroup: Self.appGroup,
                                                     propertiesManager: preferences,
                                                     vpnManagerFactory: self)
    lazy var wireGuardFactory = WireguardProtocolFactory(bundleId: Self.wireguardProviderBundleId,
                                                         appGroup: Self.appGroup,
                                                         propertiesManager: preferences,
                                                         vpnManagerFactory: self)

    lazy var vpnAuthenticationStorage = MockVpnAuthenticationStorage()
    lazy var sessionService = SessionServiceMock()

    lazy var natProvider = NATTypePropertyProviderMock()
    lazy var netShieldProvider = NetShieldPropertyProviderMock()
    lazy var safeModeProvider = SafeModePropertyProviderMock()

    lazy var vpnAuthentication = VpnAuthenticationRemoteClient(sessionService: sessionService,
                                                               authenticationStorage: vpnAuthenticationStorage,
                                                               safeModePropertyProvider: safeModeProvider)
    lazy var vpnKeychain = VpnKeychainMock(accountPlan: AccountPlan.free, maxTier: CoreAppConstants.VpnTiers.free)
    lazy var stateConfiguration = VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory,
                                                               openVpnProtocolFactory: openVpnFactory,
                                                               wireguardProtocolFactory: wireGuardFactory,
                                                               propertiesManager: preferences,
                                                               appGroup: Self.appGroup)
    lazy var alertService = CoreAlertServiceMock()
}

extension VpnManagerDependencies: VpnManagerDependencyFactories {
    func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper {
        neVpnManager.connectionWasCreated = { connection in
            connection.tunnelStateDidChange = { status in
                self.neVpnManagerConnectionStateChangeCallback?(connection, status)
            }
        }

        return neVpnManager
    }

    func makeNewManager() -> NETunnelProviderManagerWrapper {
        neTunnelProviderFactory.makeNewManager()
    }

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        neTunnelProviderFactory.loadManagersFromPreferences(completionHandler: completionHandler)
    }

    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        VpnCredentialsConfiguratorMock(vpnProtocol: vpnProtocol)
    }
}

class VpnManagerTests: XCTestCase {
    fileprivate var container: VpnManagerDependencies!
    var vpnManager: VpnManager!

    let expectationTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        container = VpnManagerDependencies()

        vpnManager = VpnManager(ikeFactory: container.ikeFactory,
                                openVpnFactory: container.openVpnFactory,
                                wireguardProtocolFactory: container.wireGuardFactory,
                                appGroup: VpnManagerDependencies.appGroup,
                                vpnAuthentication: container.vpnAuthentication,
                                vpnKeychain: container.vpnKeychain,
                                propertiesManager: container.preferences,
                                vpnStateConfiguration: container.stateConfiguration,
                                alertService: container.alertService,
                                vpnCredentialsConfiguratorFactory: container,
                                natTypePropertyProvider: container.natProvider,
                                netShieldPropertyProvider: container.netShieldProvider,
                                safeModePropertyProvider: container.safeModeProvider)

        // I have no idea why this is here. But we set it so that onDemand gets set to true
        // in the IKEv2 tests. Why onDemand should be set to false in the first IKEv2 connection
        // is currently beyond my understanding.
        container.preferences.hasConnected = true

        container.neTunnelProviderFactory.tunnelProvidersInPreferences.removeAll()
        container.neTunnelProviderFactory.tunnelProviderPreferencesData.removeAll()
    }

    func callOnTunnelProviderStateChange(closure: @escaping (NEVPNManagerMock, NEVPNConnectionMock, NEVPNStatus) -> Void) {
        container.neTunnelProviderFactory.newManagerCreated = { manager in
            manager.connectionWasCreated = { connection in
                connection.tunnelStateDidChange = { status in
                    closure(manager, connection, status)
                }
            }
        }
    }

    func callOnManagerStateChange(closure: @escaping (NEVPNManagerMock, NEVPNConnectionMock, NEVPNStatus) -> Void) {
        container.neVpnManagerConnectionStateChangeCallback = { (connection, status) in
            closure(self.container.neVpnManager, connection, status)
        }
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
                                               vpnProtocol: .wireGuard,
                                               netShield: .level1,
                                               vpnAccelerator: true,
                                               bouncing: "0",
                                               natType: .moderateNAT,
                                               safeMode: true,
                                               ports: [15213],
                                               serverPublicKey: "serverPublicKey")

        var dateConnectionEstablished: Date? = nil

        var preparingOpenVpnConnection = false
        var didDisconnectWireGuard = false
        callOnTunnelProviderStateChange { manager, connection, status in
            guard status == .connected else {
                if status == .disconnected && preparingOpenVpnConnection {
                    didDisconnectWireGuard = true
                }
                return
            }

            guard let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                XCTFail("Manager is connecting to something that does not use NETunnelProviderProtocol, definitely not WireGuard!")
                return
            }

            XCTAssertEqual(manager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(manager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(manager.isEnabled, "OpenVpn manager should be enabled")
            XCTAssert(manager.isOnDemandEnabled, "OpenVpn on demand rules should be enabled")

            XCTAssertEqual(providerProtocol.providerBundleIdentifier, VpnManagerDependencies.wireguardProviderBundleId)
            XCTAssertNil(providerProtocol.providerConfiguration)
            XCTAssertEqual(providerProtocol.serverAddress, wgConfig.entryServerAddress)

            if #available(iOS 14.2, *) {
                XCTAssertEqual(providerProtocol.includeAllNetworks, self.container.preferences.killSwitch)
                XCTAssertEqual(providerProtocol.excludeLocalNetworks, self.container.preferences.excludeLocalNetworks)
            }

            dateConnectionEstablished = connection.connectedDate
            expectations.wireguardTunnelStarted.fulfill()
        }

        vpnManager.whenReady(queue: .main) {
            self.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: wgConfig) {
                expectations.vpnManagerWireguardConnect.fulfill()
            }
        }

        wait(for: [expectations.wireguardTunnelStarted,
                   expectations.vpnManagerWireguardConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 1)
        XCTAssertEqual(vpnManager.state, .connected(.init(username: "", address: "127.0.0.1")))
        vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.wireguardConnectedDate.fulfill()
        })

        vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(enabled, "On demand should be enabled for wireguard")
            expectations.wireguardOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.wireguardConnectedDate,
                   expectations.wireguardOnDemandEnabled], timeout: expectationTimeout)

        preparingOpenVpnConnection = true
        container.preferences.killSwitch = !container.preferences.killSwitch

        let ovpnConfig = VpnManagerConfiguration(hostname: "openvpn.protonvpn.ch",
                                                 serverId: "fghij",
                                                 entryServerAddress: "127.0.0.3",
                                                 exitServerAddress: "127.0.0.4",
                                                 username: "openVpnUser",
                                                 password: "openVpnPassword",
                                                 passwordReference: Data(),
                                                 clientPrivateKey: "",
                                                 vpnProtocol: .openVpn(.udp),
                                                 netShield: .level2,
                                                 vpnAccelerator: true,
                                                 bouncing: "0",
                                                 natType: .strictNAT,
                                                 safeMode: false,
                                                 ports: [15410],
                                                 serverPublicKey: "")

        dateConnectionEstablished = nil
        var preparingIkeConnection = false
        var didDisconnectOpenVpn = false

        callOnTunnelProviderStateChange { manager, connection, status in
            guard status == .connected else {
                if status == .disconnected && preparingIkeConnection {
                    didDisconnectOpenVpn = true
                }
                return
            }

            XCTAssert(didDisconnectWireGuard, "Should have disconnected from wireguard first!")

            guard let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                XCTFail("Manager is connecting to something that does not use NETunnelProviderProtocol, definitely not OpenVpn!")
                return
            }

            XCTAssertEqual(manager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(manager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(manager.isEnabled, "OpenVpn manager should be enabled")
            XCTAssert(manager.isOnDemandEnabled, "OpenVpn on demand rules should be enabled")

            XCTAssertEqual(providerProtocol.providerBundleIdentifier, VpnManagerDependencies.openvpnProviderBundleId)
            XCTAssertEqual(providerProtocol.providerConfiguration?["appGroup"] as? String, VpnManagerDependencies.appGroup)

            let sessionConfig = providerProtocol.providerConfiguration?["sessionConfiguration"] as? [String: Any]
            XCTAssertNotNil(sessionConfig)
            XCTAssertEqual(sessionConfig?["hostname"] as? String, "127.0.0.3")
            XCTAssertEqual(providerProtocol.serverAddress, ovpnConfig.entryServerAddress)

            if #available(iOS 14.2, *) {
                XCTAssertEqual(providerProtocol.includeAllNetworks, self.container.preferences.killSwitch)
                XCTAssertEqual(providerProtocol.excludeLocalNetworks, self.container.preferences.excludeLocalNetworks)
            }

            dateConnectionEstablished = connection.connectedDate
            expectations.openVpnTunnelStarted.fulfill()
        }

        self.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: ovpnConfig) {
            expectations.vpnManagerOpenVpnConnect.fulfill()
        }

        wait(for: [expectations.openVpnTunnelStarted, expectations.vpnManagerOpenVpnConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)
        XCTAssertEqual(vpnManager.state, .connected(.init(username: "openVpnUser", address: "127.0.0.3")))
        vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.openVpnConnectedDate.fulfill()
        })

        vpnManager.isOnDemandEnabled { enabled in
            XCTAssert(enabled, "On demand should be enabled for openvpn")
            expectations.openVpnOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.openVpnConnectedDate,
                   expectations.openVpnOnDemandEnabled], timeout: expectationTimeout)

        preparingIkeConnection = true
        dateConnectionEstablished = nil

        // XXX: need to fix IKEv2 configuration bug with kill switch: gets the setting
        // from preferences instead of observing the configuration of the vpn configuration object
        container.preferences.killSwitch = !container.preferences.killSwitch

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

        callOnManagerStateChange { manager, connection, status in
            guard status == .connected else {
                return
            }

            XCTAssert(didDisconnectOpenVpn, "Should have disconnected from openvpn first!")

            let protocolConfig = manager.protocolConfiguration
            XCTAssert(protocolConfig is NEVPNProtocolIKEv2, "Protocol configuration should be for IKEv2")

            XCTAssertFalse(manager is NETunnelProviderManagerMock, "Should be base class for IKEv2")
            XCTAssertEqual(manager.onDemandRules?.count, 1, "Should contain one ondemand rule")
            XCTAssert(manager.onDemandRules?.first is NEOnDemandRuleConnect, "Should contain on demand rules")
            XCTAssert(manager.isEnabled, "IKEv2 manager should be enabled")
            XCTAssert(manager.isOnDemandEnabled, "IKEv2 on demand rules should be enabled")

            XCTAssertNil(protocolConfig?.username)
            XCTAssertNil(protocolConfig?.passwordReference)
            XCTAssertEqual(protocolConfig?.serverAddress, ikeConfig.entryServerAddress)
            if #available(iOS 14.2, *) {
                XCTAssertEqual(protocolConfig?.includeAllNetworks, self.container.preferences.killSwitch)
                XCTAssertEqual(protocolConfig?.excludeLocalNetworks, self.container.preferences.excludeLocalNetworks)
            }

            dateConnectionEstablished = connection.connectedDate
            expectations.ikeTunnelStarted.fulfill()
        }

        self.vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: ikeConfig) {
            expectations.vpnManagerIkeConnect.fulfill()
        }

        wait(for: [expectations.ikeTunnelStarted, expectations.vpnManagerIkeConnect], timeout: expectationTimeout)

        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)
        XCTAssertEqual(vpnManager.state, .connected(.init(username: "", address: "127.0.0.5")))
        vpnManager.connectedDate(completion: { date in
            XCTAssertNotNil(date)
            XCTAssertEqual(date, dateConnectionEstablished)
            expectations.ikeConnectedDate.fulfill()
        })

        vpnManager.isOnDemandEnabled { enabled in
            XCTAssertEqual(enabled, self.container.preferences.hasConnected, "On demand should be enabled for ike")
            expectations.ikeOnDemandEnabled.fulfill()
        }

        wait(for: [expectations.ikeConnectedDate,
                   expectations.ikeOnDemandEnabled], timeout: expectationTimeout)

        vpnManager.disconnect {
            expectations.ikeDisconnected.fulfill()
        }

        wait(for: [expectations.ikeDisconnected], timeout: expectationTimeout)
        XCTAssertEqual(vpnManager.state, .disconnected)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)

        vpnManager.connectedDate { nilDate in
            XCTAssertNil(nilDate)
            expectations.disconnectedNilConnectedDate.fulfill()
        }

        vpnManager.isOnDemandEnabled { enabled in
            XCTAssertFalse(enabled, "On demand should be disabled after disconnect")
            expectations.disconnectedOnDemandDisabled.fulfill()
        }

        wait(for: [expectations.disconnectedNilConnectedDate,
                   expectations.disconnectedOnDemandDisabled], timeout: expectationTimeout)

        XCTAssertNotNil(NEVPNManagerMock.whatIsSavedToPreferences)
        XCTAssertFalse(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssertEqual(container.neTunnelProviderFactory.tunnelProviderPreferencesData.count, 2)

        vpnManager.removeConfigurations { error in
            XCTAssertNil(error, "Should not receive error removing configurations")
            expectations.removedFromPreferences.fulfill()
        }

        wait(for: [expectations.removedFromPreferences], timeout: expectationTimeout)

        XCTAssertNil(NEVPNManagerMock.whatIsSavedToPreferences, "should have removed config from preferences")
        XCTAssert(container.neTunnelProviderFactory.tunnelProvidersInPreferences.isEmpty)
        XCTAssert(container.neTunnelProviderFactory.tunnelProviderPreferencesData.isEmpty)
    }
}
