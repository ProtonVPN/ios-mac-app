//
//  Created on 2022-07-13.
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

import Crypto_VPN
@testable import vpncore

class ConnectionSwitchingTests: BaseConnectionTestCase {
    func testFirstTimeConnectionWithSmartProtocol() {
        let expectations = (
            initialConnection: XCTestExpectation(description: "initial connection"),
            connectedDate: XCTestExpectation(description: "connected date"),
            certRefresh: XCTestExpectation(description: "request cert refresh"),
            disconnect: XCTestExpectation(description: "disconnected")
        )

        var currentConnection: NEVPNConnectionWrapper?
        var currentManager: NEVPNManagerWrapper?

        tunnelConnectionCreated = { connection in
            currentConnection = connection
        }

        tunnelManagerCreated = { manager in
            currentManager = manager
        }

        var didConnect = false
        statusChanged = { status in
            if status == .connected {
                didConnect = true
                expectations.initialConnection.fulfill()
            } else if status == .disconnected {
                XCTAssert(didConnect, "should have connected first")
                expectations.disconnect.fulfill()
            }
        }

        didRequestCertRefresh = { _ in
            expectations.certRefresh.fulfill()
        }

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .smartProtocol,
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil)

        container.vpnGateway.connect(with: request)

        wait(for: [expectations.initialConnection, expectations.certRefresh], timeout: expectationTimeout)

        // smart protocol should favor wireguard
        XCTAssertEqual((currentManager?.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier, MockDependencyContainer.wireguardProviderBundleId)

        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)
        XCTAssertEqual(container.alertService.alerts.count, 1)
        XCTAssert(container.alertService.alerts.first is FirstTimeConnectingAlert)

        container.vpnManager.connectedDate { date in
            XCTAssertEqual(date, currentConnection?.connectedDate)
            expectations.connectedDate.fulfill()
        }
        wait(for: [expectations.connectedDate], timeout: expectationTimeout)

        container.vpnGateway.disconnect()
        wait(for: [expectations.disconnect], timeout: expectationTimeout)
    }

    /// This test should show than when trying to determine the best port for Wireguard if pings for all the ports fail
    /// the checker tries one more time and if that succeeds the connection is established
    func testWireguardAvailablityCheckerRetryChoosingBestPortWhenAllFail() {
        let retryExpectation = XCTestExpectation()
        var seenPorts: [Int: Bool] = [:]

        container.availabilityCheckerResolverFactory.checkers[.wireGuard(.udp)]?.pingCallback = { serverIp, port in
            if seenPorts[port] == nil {
                seenPorts[port] = true
                // fail all pings on first try
                return false
            }

            // if we have seen the port being checked already then it is the second attempt
            retryExpectation.fulfill()
            // succeed all ping on second try
            return true
        }

        container.serverStorage.populateServers(container.serverStorage.servers.values + [testData.server2])

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil)

        let tunnelProviderExpectation = XCTestExpectation()

        statusChanged = { status in
            if status == .connected {
                tunnelProviderExpectation.fulfill()
            }
        }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert
        container.vpnGateway.connect(with: request)

        wait(for: [retryExpectation, tunnelProviderExpectation], timeout: 10)
        XCTAssert(container.appStateManager.state.isConnected)
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.udp))
    }

    /// This test should show than when trying to determine the best port for Wireguard if pings for all the ports fail
    /// the checker tries one more time and if the pings for all the ports fail again the connection fails with an error
    func testWireguardAvailablityCheckerRetryChoosingBestPortWhenAllFailAndFailTheConnectionWhenTheyAllFailAgain() {
        container.availabilityCheckerResolverFactory.checkers[.wireGuard(.udp)]?.pingCallback = { serverIp, port in
            // fail all the pings
            return false
        }

        container.serverStorage.populateServers(container.serverStorage.servers.values + [testData.server2])

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil)

        let stateChangedToErrorExpectation = XCTestExpectation()
        let stateChangeNotification = AppStateManagerNotification.stateChange
        let observer = NotificationCenter.default.addObserver(forName: stateChangeNotification, object: nil, queue: nil) { notification in
            guard let appState = notification.object as? AppState else {
                XCTFail("Did not send app state as part of notification")
                return
            }

            switch appState {
            case .error:
                stateChangedToErrorExpectation.fulfill()
            default:
                break
            }

        }
        defer { NotificationCenter.default.removeObserver(observer, name: stateChangeNotification, object: nil) }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert
        container.vpnGateway.connect(with: request)

        wait(for: [stateChangedToErrorExpectation], timeout: 10)
        XCTAssert(container.appStateManager.state.isDisconnected)
    }

    /// This test uses two servers and manipulates their properties and protocol availabilities to see how vpncore reacts.
    ///
    /// With two servers in the server storage, the app should pick the one with the lower score. Then, using a mocked
    /// availability checker which fakes the wireguard protocol being unavailable for that server, we should see the code
    /// decide to fall back on openvpn instead. Then we make openvpn unavailable and reconnect, at which point the code
    /// should fall back onto IKEv2. Finally, we disconnect, which should exercise the API to fetch the server list and user
    /// IP. This updated server list has placed the server we just connected to under maintenance. On the next reconnect,
    /// we go ahead and make all protocols available again, and check to see that the server chosen is not the one we were
    /// just connected to (i.e., the one with the higher score).
    func testFastestConnectionAndSmartProtocolFallbackAndDisconnectApiUsage() {
        container.availabilityCheckerResolverFactory.checkers[.wireGuard]?.availabilityCallback = { serverIp in
            // Force server2 wireguard server to be unavailable
            if serverIp == self.testData.server2.ips.first {
                return .unavailable
            }

            XCTFail("Shouldn't be checking availability for server1")
            return .available(ports: [15213, 15410])
        }

        container.serverStorage.populateServers(container.serverStorage.servers.values + [testData.server2])

        let expectations = (
            initialConnection: XCTestExpectation(description: "initial connection"),
            connectedDate: XCTestExpectation(description: "connected date"),
            reconnection: XCTestExpectation(description: "reconnection"),
            reconnectionAppStateChange: XCTestExpectation(description: "reconnect app state change"),
            disconnect: XCTestExpectation(description: "disconnect"),
            disconnectAppStateChange: XCTestExpectation(description: "disconnect app state change"),
            serverListFetch: XCTestExpectation(description: "fetch and store new servers"),
            reconnectionAfterServerInfoFetch: XCTestExpectation(description: "reconnect after manual disconnect + server info fetch"),
            wireguardCertRefresh: XCTestExpectation(description: "should refresh certificate with wireguard protocol"),
            finalConnection: XCTestExpectation(description: "final app state transition to connected"),
            finalDisconnection: XCTestExpectation(description: "final tunnel transition to disconnected")
        )

        var currentManager: NEVPNManagerMock?
        var currentStatus: NEVPNStatus?

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .smartProtocol,
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil)

        var tunnelProviderExpectation = expectations.initialConnection

        tunnelManagerCreated = { manager in
            currentManager = manager
        }

        statusChanged = { status in
            currentStatus = status
            if status == .connected {
                tunnelProviderExpectation.fulfill()
            }
        }

        didRequestCertRefresh = { _ in
            XCTFail("Should not request to refresh certificate for non-certificate-authenticated protocol")
        }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert
        container.vpnGateway.connect(with: request)

        wait(for: [tunnelProviderExpectation], timeout: expectationTimeout)

        XCTAssert(container.appStateManager.state.isConnected)

        let platformManager: NEVPNManagerMock?
        #if os(iOS)
        // wireguard was made unavailable above. protocol should fallback to openvpn
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .openVpn(.udp))
        platformManager = currentManager
        #elseif os(macOS)
        // on macos, protocol should fallback to IKEv2
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .ike)
        platformManager = container.neVpnManager
        #endif

        // server2 has a lower score, so it should connect instead of server1
        XCTAssertNotNil(platformManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(platformManager?.protocolConfiguration?.serverAddress, testData.server2.ips.first?.entryIp)
        XCTAssert(container.alertService.alerts.isEmpty)

        container.vpnManager.connectedDate { date in
            XCTAssertEqual(date, platformManager?.vpnConnection.connectedDate)
            expectations.connectedDate.fulfill()
        }
        wait(for: [expectations.connectedDate], timeout: expectationTimeout)

        let unavailableCallback = container.availabilityCheckerResolverFactory.checkers[.wireGuard]!.availabilityCallback
        #if os(iOS)
        // on iOS, force openvpn to be unavailable to force it to fallback to ike
        container.availabilityCheckerResolverFactory.checkers[.openVpn(.tcp)]?.availabilityCallback = unavailableCallback
        container.availabilityCheckerResolverFactory.checkers[.openVpn(.udp)]?.availabilityCallback = unavailableCallback
        #elseif os(macOS)
        // on macOS, force ike to be unavailable to force it to fallback to openvpn
        container.availabilityCheckerResolverFactory.checkers[.ike]?.availabilityCallback = unavailableCallback
        #endif

        statusChanged = { status in
            currentStatus = status
            expectations.reconnection.fulfill()
        }

        var observedState: AppState?
        var hasReconnected = false
        let stateChangeNotification = AppStateManagerNotification.stateChange
        let observer = NotificationCenter.default.addObserver(forName: stateChangeNotification, object: nil, queue: nil) { notification in
            guard let appState = notification.object as? AppState else {
                XCTFail("Did not send app state as part of notification")
                return
            }

            if observedState?.isDisconnected == false, appState.isDisconnected {
                expectations.disconnectAppStateChange.fulfill()
            } else if observedState?.isConnected == false, appState.isConnected {
                if !hasReconnected {
                    expectations.reconnectionAppStateChange.fulfill()
                    hasReconnected = true
                } else {
                    expectations.finalConnection.fulfill()
                }
            }
            observedState = appState
        }
        defer { NotificationCenter.default.removeObserver(observer, name: stateChangeNotification, object: nil) }

        // reconnect with netshield settings change
        container.vpnGateway.reconnect(with: NATType.strictNAT)

        wait(for: [expectations.reconnection, expectations.reconnectionAppStateChange], timeout: expectationTimeout)

        #if os(iOS)
        // on ios, protocol should fallback to IKEv2
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .ike)
        #elseif os(macOS)
        // on macos, protocol should fallback to OpenVPN
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .openVpn(.udp))
        #endif

        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server2.ips.first?.entryIp)
        XCTAssert(container.appStateManager.state.isConnected)

        container.networkingDelegate.apiServerList = [testData.server1, testData.server2UnderMaintenance]

        var storedServers: [ServerModel] = []
        container.serverStorage.didStoreNewServers = { newServers in
            storedServers = newServers
            expectations.serverListFetch.fulfill()
        }

        container.vpnGateway.disconnect {
            expectations.disconnect.fulfill()
        }

        // After disconnect, check that the results fetched from the API match the local server storage
        wait(for: [expectations.disconnect,
                   expectations.disconnectAppStateChange,
                   expectations.serverListFetch], timeout: expectationTimeout)

        XCTAssertEqual(currentStatus, .disconnected, "VPN status should be disconnected")

        XCTAssertEqual(container.serverStorage.servers.count, 2)
        let fetchedServer1 = storedServers.first(where: { $0.name == testData.server1.name })
        let fetchedServer2 = storedServers.first(where: { $0.name == testData.server2.name })

        XCTAssertEqual(fetchedServer1?.id, testData.server1.id)
        XCTAssertEqual(fetchedServer1?.status, testData.server1.status)
        XCTAssertEqual(fetchedServer2?.id, testData.server2.id)
        XCTAssertEqual(fetchedServer2?.status, testData.server2UnderMaintenance.status)

        // now we make all protocols available on all servers, so wireguard should connect now.
        container.availabilityCheckerResolverFactory.checkers[.wireGuard]?.availabilityCallback = nil
        container.availabilityCheckerResolverFactory.checkers[.openVpn(.tcp)]?.availabilityCallback = nil
        container.availabilityCheckerResolverFactory.checkers[.openVpn(.udp)]?.availabilityCallback = nil
        container.availabilityCheckerResolverFactory.checkers[.ike]?.availabilityCallback = nil

        didRequestCertRefresh = { _ in
            expectations.wireguardCertRefresh.fulfill()
        }

        statusChanged = { status in
            if status == .connected {
                tunnelProviderExpectation.fulfill()
            }
        }

        tunnelProviderExpectation = expectations.reconnectionAfterServerInfoFetch
        container.vpnGateway.connect(with: request)

        wait(for: [tunnelProviderExpectation,
                   expectations.wireguardCertRefresh,
                   expectations.finalConnection], timeout: expectationTimeout)

        // wireguard protocol now available for smart protocol to pick
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard)

        // server2 has a lower score, but has been marked as going under maintenance, so server1 should be used
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)
        XCTAssert(container.alertService.alerts.isEmpty)

        statusChanged = { status in
            if status == .disconnected {
                expectations.finalDisconnection.fulfill()
            }
        }

        container.vpnGateway.disconnect()
        wait(for: [expectations.finalDisconnection], timeout: expectationTimeout)
    }

    /// Tests user connected to a plus server. Then the plan gets downgraded to free. Supposing the user then realizes
    /// the error of their ways and upgrades back to plus, the test will then exercise the app in the case where that
    /// same user then becomes delinquent on their plan payment.
    func testUserPlanChangingThenBecomingDelinquentWithWireGuard() {
        container.serverStorage.populateServers([testData.server1, testData.server3])
        container.vpnKeychain.setVpnCredentials(with: .plus, maxTier: CoreAppConstants.VpnTiers.plus)
        container.propertiesManager.vpnProtocol = .wireGuard
        container.propertiesManager.hasConnected = true

        let (totalConnections, totalDisconnections) = (4, 4)
        let expectations = (
            connections: (1...totalConnections).map { XCTestExpectation(description: "connection \($0)") },
            appStateConnectedTransitions: (1...totalConnections).map { XCTestExpectation(description: "app state transition -> connected \($0)") },
            disconnections: (1...totalDisconnections).map { XCTestExpectation(description: "disconnection \($0)") },
            downgradeAlert: XCTestExpectation(description: "downgraded alert"),
            delinquentAlert: XCTestExpectation(description: "delinquent alert"),
            upgradeNotification: XCTestExpectation(description: "notify upgrade state")
        )

        var downgradedAlert: UserPlanDowngradedAlert?
        var delinquentAlert: UserBecameDelinquentAlert?

        container.alertService.alertAdded = { alert in
            if let downgraded = alert as? UserPlanDowngradedAlert {
                downgradedAlert = downgraded
                expectations.downgradeAlert.fulfill()
            } else if let delinquent = alert as? UserBecameDelinquentAlert {
                delinquentAlert = delinquent
                expectations.delinquentAlert.fulfill()
            } else {
                XCTFail("Unexpected alert.")
            }
        }

        container.localAgentConnectionFactory.connectionWasCreated = { connection in
            let consts = LocalAgentConstants()!
            DispatchQueue.main.async {
                connection.client.onState(consts.stateConnecting)
            }
            DispatchQueue.main.async {
                connection.client.onState(consts.stateConnected)
            }
        }

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .vpnProtocol(.wireGuard),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil)

        var (nConnections,
             nDisconnections,
             nAppStateConnectTransitions) = (0, 0, 0)

        let stateChangeNotification = AppStateManagerNotification.stateChange
        var observedStates: [AppState] = []
        let observer = NotificationCenter.default.addObserver(forName: stateChangeNotification, object: nil, queue: nil) { notification in
            guard let appState = notification.object as? AppState else { return }
            defer { observedStates.append(appState) }
            // debounce multiple "connected" notifications... we should probably fix that
            if case .connected = appState {
                if case .connected = observedStates.last { return }

                guard nAppStateConnectTransitions < totalConnections else {
                    XCTFail("Didn't expect that many (\(nAppStateConnectTransitions + 1)) connection transitions - " +
                            "previous observed states \(observedStates.map { $0.description })")
                    return
                }

                expectations.appStateConnectedTransitions[nAppStateConnectTransitions].fulfill()
                nAppStateConnectTransitions += 1
            }
        }
        defer { NotificationCenter.default.removeObserver(observer, name: stateChangeNotification, object: nil) }

        var observedStatuses: [NEVPNStatus] = []
        var currentManager: NETunnelProviderManagerMock?

        tunnelManagerCreated = { manager in
            currentManager = manager
        }

        statusChanged = { vpnStatus in
            defer { observedStatuses.append(vpnStatus) }

            switch vpnStatus {
            case .connected:
                defer { nConnections += 1 }
                guard nConnections < totalConnections else {
                    XCTFail("Didn't expect that many (\(nConnections + 1)) connection transitions - " +
                            "previous statuses \(observedStatuses.map { $0.description })")
                    return
                }
                expectations.connections[nConnections].fulfill()
            case .disconnected:
                defer { nDisconnections += 1 }
                guard nDisconnections < totalDisconnections else {
                    XCTFail("Didn't expect that many (\(nDisconnections + 1)) disconnection transitions - " +
                            "previous statuses \(observedStatuses.map { $0.description })")
                    return
                }
                expectations.disconnections[nDisconnections].fulfill()
            default:
                break
            }

        }
        container.vpnGateway.connect(with: request)
        wait(for: [expectations.connections[0],
                   expectations.appStateConnectedTransitions[0]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 1)

        // should be connected to plus server
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server3.ips.first?.entryIp)

        let plusCreds = try! container.vpnKeychain.fetch()
        XCTAssertEqual(plusCreds.accountPlan, .plus)
        XCTAssertEqual(plusCreds.maxTier, CoreAppConstants.VpnTiers.plus)

        let freeCreds = VpnKeychainMock.vpnCredentials(accountPlan: .free,
                                                       maxTier: CoreAppConstants.VpnTiers.free)
        container.networkingDelegate.apiCredentials = freeCreds

        let downgrade: VpnDowngradeInfo = (plusCreds, freeCreds)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: VpnKeychainMock.vpnPlanChanged, object: downgrade)
            self.container.vpnKeychain.credentials = freeCreds
            NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: freeCreds)
        }

        wait(for: [expectations.disconnections[0],
                   expectations.downgradeAlert], timeout: expectationTimeout)
        XCTAssertEqual(nDisconnections, 1)
        container.alertService.alerts.removeAll()

        guard let downgradedAlert = downgradedAlert, let reconnectInfo = downgradedAlert.reconnectInfo else {
            XCTFail("Downgraded alert not found or reconnect info not found in downgraded alert")
            return
        }

        XCTAssertEqual(reconnectInfo.fromServer.name, testData.server3.name)
        XCTAssertEqual(reconnectInfo.toServer.name, testData.server1.name)

        wait(for: [expectations.connections[1],
                   expectations.appStateConnectedTransitions[1]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 2)

        // Should have reconnected to server1 now that the user tier has changed
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)

        // Even if it's an upgrade, it's still called "VpnDowngradeInfo" *shrug*
        let upgrade: VpnDowngradeInfo = (freeCreds, plusCreds)
        container.networkingDelegate.apiCredentials = plusCreds

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: VpnKeychainMock.vpnPlanChanged, object: upgrade)
            self.container.vpnKeychain.credentials = plusCreds
            NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: plusCreds)
            expectations.upgradeNotification.fulfill()
        }

        wait(for: [expectations.upgradeNotification], timeout: expectationTimeout)

        container.vpnGateway.disconnect()
        wait(for: [expectations.disconnections[1]], timeout: expectationTimeout)
        XCTAssertEqual(nDisconnections, 2)

        container.vpnGateway.connect(with: request)
        wait(for: [expectations.connections[2],
                   expectations.appStateConnectedTransitions[2]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 3)

        // Should have reconnected to server3 now that the user is again eligible
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server3.ips.first?.entryIp)

        container.networkingDelegate.apiCredentials = freeCreds
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: VpnKeychainMock.vpnUserDelinquent, object: downgrade)
            self.container.vpnKeychain.credentials = freeCreds
            NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: freeCreds)
        }

        wait(for: [expectations.disconnections[2],
                   expectations.delinquentAlert], timeout: expectationTimeout)
        XCTAssertEqual(nDisconnections, 3)
        // and should have received an alert stating which server the app reconnected to
        XCTAssertEqual(delinquentAlert?.reconnectInfo?.fromServer.name, testData.server3.name)
        XCTAssertEqual(delinquentAlert?.reconnectInfo?.toServer.name, testData.server1.name)

        wait(for: [expectations.connections[3],
                   expectations.appStateConnectedTransitions[3]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 4)

        // Should have reconnected to server1 now that user is delinquent
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)

        container.vpnGateway.disconnect()
        wait(for: [expectations.disconnections[3]], timeout: expectationTimeout)
    }
}
