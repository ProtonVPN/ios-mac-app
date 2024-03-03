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
import NetworkExtension
import XCTest

import Dependencies

import GoLibs
import ProtonCoreServices
import ProtonCoreNetworking

import Domain
import VPNShared
import VPNSharedTesting

@testable import LegacyCommon

class ConnectionSwitchingTests: BaseConnectionTestCase {
    override func setUpWithError() throws {
        #if os(macOS)
        throw XCTSkip("Connection switching tests are skipped on macOS, since there is no cert refresh provider.")
        #endif
        try super.setUpWithError()
    }

    func testFirstTimeConnectionWithSmartProtocol() async {
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

        let request = ConnectionRequest(
            serverType: .standard,
            connectionType: .country("CH", .fastest),
            connectionProtocol: .smartProtocol,
            netShieldType: .level1,
            natType: .moderateNAT,
            safeMode: true,
            profileId: nil,
            trigger: .country
        )

        await MainActor.run { processGatewayConnectionRequestWithOverriddenDependencies(request: request) }
        await fulfillment(of: [expectations.initialConnection, expectations.certRefresh], timeout: expectationTimeout)

        // smart protocol should favor wireguard
        XCTAssertEqual((currentManager?.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier, MockDependencyContainer.wireguardProviderBundleId)

        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)
        XCTAssertEqual(container.alertService.alerts.count, 0)

        let date = await container.vpnManager.connectedDate()
        XCTAssertEqual(date, currentConnection?.connectedDate)

        container.vpnGateway.disconnect()
        await fulfillment(of: [expectations.disconnect], timeout: expectationTimeout)
    }

    /// This test should show than when trying to determine the best port for Wireguard if pings for all the ports fail
    /// the checker tries one more time and if that succeeds the connection is established
    func testWireguardAvailablityCheckerRetryChoosingBestPortWhenAllFail() throws {
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

        try repository.upsert(servers: [VPNServer(legacyModel: testData.server2)])

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil,
                                        trigger: .country)

        let tunnelProviderExpectation = XCTestExpectation()

        statusChanged = { status in
            if status == .connected {
                tunnelProviderExpectation.fulfill()
            }
        }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)

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

        repository.upsert(servers: [VPNServer(legacyModel: testData.server2)])

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil,
                                        trigger: .country)

        let stateChangedToErrorExpectation = XCTestExpectation()
        let observer = NotificationCenter.default.addObserver(forName: .AppStateManager.stateChange, object: nil, queue: nil) { notification in
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

        defer { NotificationCenter.default.removeObserver(observer, name: .AppStateManager.stateChange, object: nil) }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert
        processGatewayConnectionRequestWithOverriddenDependencies(request: request)

        wait(for: [stateChangedToErrorExpectation], timeout: 10)
        XCTAssert(container.appStateManager.state.isDisconnected)
    }

    /// This test uses two servers and manipulates their properties and protocol availabilities to see how vpncore reacts.
    ///
    /// With two servers in the server storage, the app should pick the one with the lower score. Then, using a mocked
    /// availability checker which fakes the wireguard protocol being unavailable for that server, we should see the
    /// code decide to fall back to IKEv2 on MacOS and Stealth on iOS.
    ///
    /// Then we make the previously chosen protocol unavailable and reconnect, at which point the code should fall back
    /// onto Stealth on MacOS, and WireGuard TCP on iOS.
    ///
    /// Finally, we disconnect, which should exercise the API to fetch the server list and user IP. This updated server
    /// list has placed the server we just connected to under maintenance. On the next reconnect, we go ahead and make
    /// all protocols available again, and check to see that the server chosen is not the one we were just connected to
    /// (i.e., the one with the higher score).
    @MainActor
    func testFastestConnectionAndSmartProtocolFallbackAndDisconnectApiUsage() async throws { // swiftlint:disable:this function_body_length
        let unavailableCallback: AvailabilityCheckerMock.AvailabilityCallback = { serverIp in
            // Force server2 wireguard server to be unavailable
            if serverIp.id == self.testData.server2.ips.first?.id {
                return .unavailable
            }

            XCTFail("Shouldn't be checking availability for server1")
            return .available(ports: [15213, 15410])
        }

        container.availabilityCheckerResolverFactory.checkers[.wireGuard(.udp)]?.availabilityCallback = unavailableCallback

        try repository.upsert(servers: [VPNServer(legacyModel: testData.server2)])

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
                                        profileId: nil,
                                        trigger: .country)

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
            #if os(macOS)
            // MasOS should connect with IKE
            XCTFail("Should not request to refresh certificate for non-certificate-authenticated protocol")
            #endif
        }

        container.propertiesManager.hasConnected = true // check that we don't display FirstTimeConnectingAlert
        processGatewayConnectionRequestWithOverriddenDependencies(request: request)

        var connectionExpectations = [tunnelProviderExpectation]
        await fulfillment(of: connectionExpectations, timeout: expectationTimeout)

        XCTAssert(container.appStateManager.state.isConnected)

        let platformManager: NEVPNManagerMock?
        #if os(iOS)
        // wireguard was made unavailable above. protocol should fallback to wireguard TLS
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.tls))
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

        let date = await container.vpnManager.connectedDate()
        XCTAssertEqual(date, platformManager?.vpnConnection.connectedDate)

        didRequestCertRefresh = { _ in }

        #if os(iOS)
        // on iOS, force TLS to be unavailable to force it to fallback to TCP
        container.availabilityCheckerResolverFactory.checkers[.wireGuard(.tls)]?.availabilityCallback = unavailableCallback
        #elseif os(macOS)
        // on macOS, force ike to be unavailable to force it to fallback to wireguard TLS
        container.availabilityCheckerResolverFactory.checkers[.ike]?.availabilityCallback = unavailableCallback
        #endif

        statusChanged = { status in
            currentStatus = status
            expectations.reconnection.fulfill()
        }
        Task {
            var observedState: AppState?
            var hasReconnected = false

            for await notification in NotificationCenter.default.notifications(named: .AppStateManager.stateChange, object: nil) {
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
        }

        // reconnect with netshield settings change
        withDependencies({ $0.serverRepository = repository }, operation: {
            container.vpnGateway.reconnect(with: NATType.strictNAT)
        })

        connectionExpectations = [expectations.reconnection, expectations.reconnectionAppStateChange]
        await fulfillment(of: connectionExpectations, timeout: expectationTimeout)

        #if os(iOS)
        // on ios, protocol should fallback to WireGuard TCP
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.tcp))
        #elseif os(macOS)
        // on macos, protocol should fallback to WireGuard TLS
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.tls))
        #endif

        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server2.ips.first?.entryIp)
        XCTAssert(container.appStateManager.state.isConnected)

        container.networkingDelegate.apiServerList = [testData.server1, testData.server2UnderMaintenance]

        var storedServers: [ServerModel] = []
        repositoryWrapper.didStoreServers = { newServers in
            storedServers = newServers.map { ServerModel(server: $0) }
            expectations.serverListFetch.fulfill()
        }

        disconnectGatewayWithOverriddenDependencies {
            expectations.disconnect.fulfill()
        }

        // After disconnect, check that the results fetched from the API match the local server storage
        await fulfillment(of: [expectations.disconnect, expectations.disconnectAppStateChange], timeout: expectationTimeout)

        XCTAssertEqual(currentStatus, .disconnected, "VPN status should be disconnected")

        // TODO: Why does awaiting this expectation cause mocked `VPNLogicalServicesRequest` to take over 3s?
        await fulfillment(of: [expectations.serverListFetch], timeout: expectationTimeout)

        XCTAssertEqual(try repositoryWrapper.serverCount, 2)
        let fetchedServer1 = storedServers.first(where: { $0.name == testData.server1.name })
        let fetchedServer2 = storedServers.first(where: { $0.name == testData.server2.name })

        XCTAssertEqual(fetchedServer1?.id, testData.server1.id)
        XCTAssertEqual(fetchedServer1?.status, testData.server1.status)
        XCTAssertEqual(fetchedServer2?.id, testData.server2.id)
        XCTAssertEqual(fetchedServer2?.status, testData.server2UnderMaintenance.status)

        // now we make all protocols available on all servers, so wireguard should connect now.
        VpnProtocol.allCases.forEach { container.availabilityCheckerResolverFactory.checkers[$0]?.availabilityCallback = nil }

        didRequestCertRefresh = { _ in
            expectations.wireguardCertRefresh.fulfill()
        }

        statusChanged = { status in
            if status == .connected {
                tunnelProviderExpectation.fulfill()
            }
        }

        tunnelProviderExpectation = expectations.reconnectionAfterServerInfoFetch
        processGatewayConnectionRequestWithOverriddenDependencies(request: request)

        await fulfillment(of: [tunnelProviderExpectation, expectations.finalConnection], timeout: expectationTimeout)

        // wireguard protocol now available for smart protocol to pick
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.udp))

        // server2 has a lower score, but has been marked as going under maintenance, so server1 should be used
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        // Re-enable this assertion once VPNServerSelector uses ServerRepository and not the file based ServerStorage.
        // XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)
        XCTAssert(container.alertService.alerts.isEmpty)

        statusChanged = { status in
            if status == .disconnected {
                expectations.finalDisconnection.fulfill()
            }
        }

        container.vpnGateway.disconnect()

        await fulfillment(of: [expectations.finalDisconnection], timeout: expectationTimeout)
    }

    func retrieveAndSetVpnProperties() async {
        let expectation = XCTestExpectation(description: "Retrieves VPN properties")

        do {
        let vpnProperties = try await container.vpnApiService.vpnProperties(isDisconnected: true, lastKnownLocation: nil, serversAccordingToTier: true)
            defer { expectation.fulfill() }
            container.propertiesManager.featureFlags = vpnProperties.clientConfig!.featureFlags
            container.propertiesManager.smartProtocolConfig = vpnProperties.clientConfig!.smartProtocolConfig
        } catch {
            XCTFail("Could not get vpn properties")
        }

        await fulfillment(of: [expectation], timeout: expectationTimeout)
    }

    // Test that Smart Protocol doesn't use WireGuard TLS when it's disabled in feature flags.
    @MainActor
    func testSmartProtocolRespectsAPIConfig() async { // swiftlint:disable:this function_body_length
        PMAPIService.noTrustKit = true // disabling trustKit, otherwise it will trigger this `assertionFailure("TrustKit not initialized correctly")`
        let isConnectedUsingTcpOrTls: () -> Bool = {
            [.wireGuard(.tls), .wireGuard(.tcp)].contains(self.container.vpnManager.currentVpnProtocol)
        }

        let unavailableCallback: AvailabilityCheckerMock.AvailabilityCallback = { _ in
            .unavailable
        }

        let unavailableProtocols: [VpnProtocol] = [
            .ike,
            .openVpn(.tcp),
            .openVpn(.udp),
            .wireGuard(.udp)
        ]

        for vpnProtocol in unavailableProtocols {
            container.availabilityCheckerResolverFactory.checkers[vpnProtocol]?.availabilityCallback = unavailableCallback
        }

        let expectations = (
            connection: (1...5).map { XCTestExpectation(description: "connection #\($0)") },
            clientConfig: (1...5).map { XCTestExpectation(description: "fetch client config #\($0)") },
            disconnect: (1...5).map { XCTestExpectation(description: "disconnect #\($0)") }
        )
        let protocolAlertExpectation = XCTestExpectation(description: "Protocol not supported alert should be shown")
        protocolAlertExpectation.expectedFulfillmentCount = 1

        var didConnect = false
        var step = 0
        statusChanged = { status in
            if status == .connected {
                didConnect = true
                expectations.connection[step].fulfill()
            } else if status == .disconnected {
                XCTAssert(didConnect, "should have connected first")
                expectations.disconnect[step].fulfill()
            }
        }

        container.networkingDelegate.didHitRoute = { route in
            guard route == .clientConfig else { return }

            expectations.clientConfig[step].fulfill()
        }

        container.alertService.alertAdded = { alert in
            if alert is ProtocolNotAvailableForServerAlert {
                protocolAlertExpectation.fulfill()
            } else {
                XCTFail("Unexpected alert. \(type(of: alert))")
            }
        }

        let request = ConnectionRequest(serverType: .standard,
                                        connectionType: .country("CH", .fastest),
                                        connectionProtocol: .smartProtocol,
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil,
                                        trigger: .country)

        // Feature flag disables all protocols allowed by API config (contradictory setup edge case)
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
            .with(featureFlags: .wireGuardTlsDisabled, smartProtocolConfig: .onlyWgTcpAndTls)
        container.authKeychain.setMockUsername("user")
        let freeCreds = VpnKeychainMock.vpnCredentials(planName: "free",
                                                       maxTier: .freeTier)
        container.networkingDelegate.apiCredentials = freeCreds

        await retrieveAndSetVpnProperties()

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        await fulfillment(of: [expectations.clientConfig[step], protocolAlertExpectation], timeout: expectationTimeout)

        step += 1

        // Feature flag disables TLS, connection should use another protocol
        container.networkingDelegate.apiClientConfig = testData.clientConfigNoWireGuardTls
        await retrieveAndSetVpnProperties()
        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        await fulfillment(of: [expectations.connection[step], expectations.clientConfig[step]], timeout: expectationTimeout)

        XCTAssertFalse(container.propertiesManager.featureFlags.wireGuardTls)
        XCTAssertFalse(isConnectedUsingTcpOrTls())

        container.vpnGateway.disconnect()
        await fulfillment(of: [expectations.disconnect[step]], timeout: expectationTimeout)

        step += 1

        // Enable feature flag, but disable TCP and TLS in API config. Connection should use another protocol again
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
            .with(smartProtocolConfig: .onlyIke)
        await retrieveAndSetVpnProperties()
        XCTAssertEqual(self.container.propertiesManager.smartProtocolConfig, .onlyIke)

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        await fulfillment(of: [expectations.connection[step], expectations.clientConfig[step]], timeout: expectationTimeout)

        XCTAssertTrue(container.propertiesManager.featureFlags.wireGuardTls)
        XCTAssertFalse(isConnectedUsingTcpOrTls())

        container.vpnGateway.disconnect()
        await fulfillment(of: [expectations.disconnect[step]], timeout: expectationTimeout)

        step += 1

        // Now enable the feature flag and protocols in smart config, and try reconnecting with smart protocol.
        // Resulting connection should be using wireguard with tls, when tcp is unavailable
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
        container.availabilityCheckerResolverFactory.checkers[.wireGuard(.tcp)]?.availabilityCallback = unavailableCallback
        await retrieveAndSetVpnProperties()

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        await fulfillment(of: [expectations.connection[step], expectations.clientConfig[step]], timeout: expectationTimeout)

        XCTAssert(container.propertiesManager.featureFlags.wireGuardTls)
        XCTAssertEqual(container.vpnManager.currentVpnProtocol, .wireGuard(.tls))

        container.vpnGateway.disconnect()
        await fulfillment(of: [expectations.disconnect[step]], timeout: expectationTimeout)

        step += 1

        // Test common config for restricted countries (only WireGuard TCP and TLS enabled). Should connect with TCP or TLS
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
            .with(smartProtocolConfig: .onlyWgTcpAndTls)
        await retrieveAndSetVpnProperties()

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        await fulfillment(of: [expectations.connection[step], expectations.clientConfig[step]], timeout: expectationTimeout)

        XCTAssert(isConnectedUsingTcpOrTls())
        XCTAssert(container.propertiesManager.featureFlags.wireGuardTls)

        container.vpnGateway.disconnect()
        await fulfillment(of: [expectations.disconnect[step]], timeout: expectationTimeout)
    }

    /// Tests user connected to a plus server. Then the plan gets downgraded to free. Supposing the user then realizes
    /// the error of their ways and upgrades back to plus, the test will then exercise the app in the case where that
    /// same user then becomes delinquent on their plan payment.
    func testUserPlanChangingThenBecomingDelinquentWithWireGuard() throws { // swiftlint:disable:this function_body_length cyclomatic_complexity
        // This test is skipped as it requires the `Task` in `VpnGateway.userBecameDelinquent` to be modified to
        // propagate dependencies using `withEscapedDependencies` or capture self and use `withDependencies`.
        // When this is done, the test passes as expected
        throw XCTSkip("Skipped due to dependency awkwardness")

        let initialServers = [testData.server1, testData.server3]
        container.networkingDelegate.apiServerList = initialServers
        try repository.upsert(servers: initialServers.map { VPNServer(legacyModel: $0) })

        container.vpnKeychain.setVpnCredentials(with: "plus", maxTier: .paidTier)
        container.propertiesManager.vpnProtocol = .wireGuard(.udp)
        container.propertiesManager.hasConnected = true
        container.authKeychain.setMockUsername("user")

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
                                        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                        netShieldType: .level1,
                                        natType: .moderateNAT,
                                        safeMode: true,
                                        profileId: nil,
                                        trigger: .country)

        var (nConnections,
             nDisconnections,
             nAppStateConnectTransitions) = (0, 0, 0)

        var observedStates: [AppState] = []
        let observer = NotificationCenter.default.addObserver(forName: .AppStateManager.stateChange, object: nil, queue: nil) { notification in
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
        defer { NotificationCenter.default.removeObserver(observer, name: .AppStateManager.stateChange, object: nil) }

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
        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        wait(for: [expectations.connections[0], expectations.appStateConnectedTransitions[0]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 1)

        // should be connected to plus server
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server3.ips.first?.entryIp)

        let plusCreds = try! container.vpnKeychain.fetch()
        XCTAssertEqual(plusCreds.planName, "plus")
        XCTAssertEqual(plusCreds.maxTier, .paidTier)

        let freeCreds = VpnKeychainMock.vpnCredentials(planName: "free",
                                                       maxTier: .freeTier)
        container.networkingDelegate.apiCredentials = freeCreds

        let downgrade: VpnDowngradeInfo = (plusCreds, freeCreds)
        DispatchQueue.main.async {
            withDependencies({ $0.serverRepository = self.repository }, operation: {
                NotificationCenter.default.post(name: VpnKeychainMock.vpnPlanChanged, object: downgrade)
                self.container.vpnKeychain.credentials = freeCreds
                NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: freeCreds)
            })
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

        disconnectGatewayWithOverriddenDependencies()
        wait(for: [expectations.disconnections[1]], timeout: expectationTimeout)
        XCTAssertEqual(nDisconnections, 2)

        processGatewayConnectionRequestWithOverriddenDependencies(request: request)
        wait(for: [expectations.connections[2],
                   expectations.appStateConnectedTransitions[2]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 3)

        // Should have reconnected to server3 now that the user is again eligible
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server3.ips.first?.entryIp)

        container.networkingDelegate.apiCredentials = freeCreds
        DispatchQueue.main.async {
            withDependencies({ $0.serverRepository = self.repository }, operation: {
                NotificationCenter.default.post(name: VpnKeychainMock.vpnUserDelinquent, object: downgrade)
                self.container.vpnKeychain.credentials = freeCreds
                NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: freeCreds)
            })
        }

        wait(for: [expectations.disconnections[2], expectations.delinquentAlert], timeout: expectationTimeout)
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

        disconnectGatewayWithOverriddenDependencies()
        wait(for: [expectations.disconnections[3]], timeout: expectationTimeout)
    }

    func testUserPlanChangingFromFreeToPlusAndConnectingToPaidServerThruQuickConnect() { // swiftlint:disable:this function_body_length
        container.networkingDelegate.apiServerList = [testData.server1, testData.server3]

        container.vpnKeychain.setVpnCredentials(with: "free", maxTier: .freeTier)
        container.propertiesManager.vpnProtocol = .wireGuard(.udp)
        container.propertiesManager.hasConnected = true
        container.authKeychain.setMockUsername("user")

        let freeCreds = try! container.vpnKeychain.fetch()
        XCTAssertEqual(freeCreds.planName, "free")
        XCTAssertEqual(freeCreds.maxTier, .freeTier)

        let plusCreds = VpnKeychainMock.vpnCredentials(planName: "plus", maxTier: .paidTier)

        let (totalConnections, totalDisconnections) = (2, 2)

        let expectations = (
            connections: (1...totalConnections).map { XCTestExpectation(description: "connection \($0)") },
            appStateConnectedTransitions: (1...totalConnections).map { XCTestExpectation(description: "app state transition -> connected \($0)") },
            disconnections: (1...totalDisconnections).map { XCTestExpectation(description: "disconnection \($0)") },
            serverSaves: (1...totalConnections + 1).map { XCTestExpectation(description: "server list store \($0)") },
            upgradeNotification: XCTestExpectation(description: "notify upgrade state"),
            refreshLogicalsAfterPlanUpgrade: XCTestExpectation(description: "refresh logicals after plan upgrade")
        )

        container.localAgentConnectionFactory.connectionWasCreated = { connection in
            let consts = LocalAgentConstants()!
            DispatchQueue.main.async {
                connection.client.onState(consts.stateConnecting)
            }
            DispatchQueue.main.async {
                connection.client.onState(consts.stateConnected)
            }
        }

        var (nConnections,
             nDisconnections,
             nServerSaves,
             nAppStateConnectTransitions) = (0, 0, 0, 0)

        var storedServers: [ServerModel] = []
        repositoryWrapper.didStoreServers = { newServers in
            DispatchQueue.main.async {
                storedServers = newServers.map { ServerModel(server: $0) }
                expectations.serverSaves[nServerSaves].fulfill()
                nServerSaves += 1
            }
        }

        var observedStates: [AppState] = []
        let observer = NotificationCenter.default.addObserver(forName: .AppStateManager.stateChange, object: nil, queue: nil) { notification in
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
        defer { NotificationCenter.default.removeObserver(observer, name: .AppStateManager.stateChange, object: nil) }

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

        container.appSessionRefreshTimer.startTimers()
        container.timerFactory.runRepeatingTimers()

        withDependencies {
            $0.authKeychain = MockAuthKeychain()
            $0.serverRepository = repository
        } operation: {
            container.vpnGateway.quickConnect(trigger: .newConnection)
        }

        wait(
            for: [
                expectations.connections[0],
                expectations.appStateConnectedTransitions[0],
                expectations.serverSaves[0]
            ],
            timeout: expectationTimeout
        )
        XCTAssertEqual(nConnections, 1)
        XCTAssertEqual(storedServers.count, 1) // Just the free server
        XCTAssertEqual(storedServers.first?.isFree, true)

        // Should connect to server1, that's the only thing in the server list
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server1.ips.first?.entryIp)

        disconnectGatewayWithOverriddenDependencies()
        wait(for: [expectations.disconnections[0]], timeout: expectationTimeout)
        XCTAssertEqual(nDisconnections, 1)

        container.networkingDelegate.apiCredentials = plusCreds

        container.networkingDelegate.didHitRoute = { route in
            guard route == .logicals else { return }

            expectations.refreshLogicalsAfterPlanUpgrade.fulfill()
        }

        DispatchQueue.main.async {
            let upgrade: VpnDowngradeInfo = (freeCreds, plusCreds)
            self.container.vpnKeychain.credentials = plusCreds
            NotificationCenter.default.post(name: VpnKeychainMock.vpnPlanChanged, object: upgrade)

            NotificationCenter.default.post(name: VpnKeychainMock.vpnCredentialsChanged, object: plusCreds)
            expectations.upgradeNotification.fulfill()
        }

        // The plan upgrade should force the system to refresh the (now larger) server list
        wait(
            for: [
                expectations.upgradeNotification,
                expectations.refreshLogicalsAfterPlanUpgrade,
                expectations.serverSaves[1]
            ],
            timeout: expectationTimeout
        )

        withDependencies({ $0.serverRepository = repository }, operation: {
            container.vpnGateway.quickConnect(trigger: .newConnection)
        })
        wait(
            for: [expectations.connections[1], expectations.appStateConnectedTransitions[1]],
            timeout: expectationTimeout
        )
        XCTAssertEqual(nConnections, 2)

        // Quick connect should now prefer the plus server
        XCTAssertNotNil(currentManager?.protocolConfiguration?.serverAddress)
        XCTAssertEqual(currentManager?.protocolConfiguration?.serverAddress, testData.server3.ips.first?.entryIp)
        disconnectGatewayWithOverriddenDependencies()

        wait(for: [expectations.disconnections[1]], timeout: expectationTimeout)
    }

    func testFreeUserImmediateReconnectsAreThrottledAccordingToClientConfig() async { // swiftlint:disable:this function_body_length
        container.authKeychain.setMockUsername("user")
        container.vpnKeychain.setVpnCredentials(with: "free", maxTier: .freeTier)

        let oldAuthKeychain = AuthKeychainHandleDependencyKey.testValue
        AuthKeychainHandleDependencyKey.testValue = container.authKeychain
        let oldCredentialsProvider = CredentialsProvider.testValue
        CredentialsProvider.testValue = .constant(credentials: .tier(.freeTier))

        var until: Date?
        var observedStatuses: [NEVPNStatus] = []
        var nAlerts = 0
        var nConnections = 0
        var nDisconnections = 0
        let totalAlerts = 2
        let totalConnections = 1
        let totalDisconnections = totalConnections

        let expectations = (
            alerts: (1...totalAlerts).map {
                XCTestExpectation(description: "Alert \($0)/\(totalAlerts)")
            },
            connections: (1...totalConnections).map {
                XCTestExpectation(description: "Connection \($0)/\(totalConnections)")
            },
            disconnections: (1...totalConnections).map {
                XCTestExpectation(description: "Disconnection \($0)/\(totalConnections)")
            }
        )

        container.alertService.alertAdded = {
            guard let alert = $0 as? ConnectionCooldownAlert else {
                return
            }

            guard nAlerts < totalAlerts else {
                XCTFail("Didn't expect that many (\(nAlerts + 1)) alerts displayed")
                return
            }

            until = alert.until
            expectations.alerts[nAlerts].fulfill()
            nAlerts += 1
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

        // We want to create a different one every time so the request UUID can change.
        let randomConnectionRequest = {
            ConnectionRequest(
                serverType: .standard,
                connectionType: .random,
                connectionProtocol: .smartProtocol,
                netShieldType: .off,
                natType: .moderateNAT,
                safeMode: false,
                profileId: nil,
                trigger: nil
            )
        }

        await MainActor.run {
            withDependencies {
                $0.date = .constant(Date())
                $0.serverRepository = repository
                $0.featureFlagProvider = .constant(flags: .allEnabled)
            } operation: {
                container.vpnGateway.connect(
                    with: randomConnectionRequest()
                )
            }
        }

        await fulfillment(of: [expectations.connections[0]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 1)

        disconnectGatewayWithOverriddenDependencies()
        await fulfillment(of: [expectations.disconnections[0]], timeout: expectationTimeout)
        XCTAssertEqual(nConnections, 1)
        XCTAssertEqual(nDisconnections, 1)

        let date = Date()
        await MainActor.run {
            withDependencies {
                $0.date = .constant(date)
                $0.serverRepository = repository
                $0.featureFlagProvider = .constant(flags: .allEnabled)
            } operation: {
                container.vpnGateway.connect(
                    with: randomConnectionRequest()
                )
            }
        }
        await fulfillment(of: [expectations.alerts[0]], timeout: expectationTimeout)
        // We shouldn't have connected, and we should have received a cooldown alert
        XCTAssertEqual(nConnections, 1)

        @Dependency(\.serverChangeStorage) var serverChangeStorage
        let epsilon: TimeInterval = 1
        let untilDate = until?.timeIntervalSince1970 ?? 0
        let expectedUntilDate = date
            .addingTimeInterval(TimeInterval(serverChangeStorage.config.changeServerShortDelayInSeconds))
            .timeIntervalSince1970
        XCTAssertLessThan(abs(untilDate - expectedUntilDate), epsilon)

        await MainActor.run {
            withDependencies {
                $0.date = .constant(date)
                $0.featureFlagProvider = .constant(flags: .allEnabled)

                // Now add a bunch of connections to the stack, we should get the longer delay
                // We already have one server change in the stack, so add one less than the limit
                let connectionsToAdd = $0.serverChangeStorage.config.changeServerAttemptLimit - 1
                for i in 0..<connectionsToAdd {
                    $0.serverChangeAuthorizer.registerServerChange(connectedAt: date
                        .addingTimeInterval(TimeInterval(
                            -(connectionsToAdd - i - 1) *
                             serverChangeStorage
                                .config
                                .changeServerShortDelayInSeconds
                        ))
                    )
                }
            } operation: {
                container.vpnGateway.connect(
                    with: randomConnectionRequest()
                )
            }
        }

        await fulfillment(of: [expectations.alerts[1]], timeout: expectationTimeout)

        let longUntilDate = until?.timeIntervalSince1970 ?? 0
        let expectedLongUntilDate = date
            .addingTimeInterval(TimeInterval(serverChangeStorage.config.changeServerLongDelayInSeconds))
            .timeIntervalSince1970

        let diff = abs(longUntilDate - expectedLongUntilDate)
        XCTAssertLessThan(
            diff,
            epsilon,
            "\(longUntilDate) is not equal to expected value \(expectedLongUntilDate) (difference of \(diff))"
        )

        CredentialsProvider.testValue = oldCredentialsProvider
        AuthKeychainHandleDependencyKey.testValue = oldAuthKeychain
    }
}
