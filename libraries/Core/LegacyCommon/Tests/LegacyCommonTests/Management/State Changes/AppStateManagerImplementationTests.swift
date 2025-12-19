//
//  AppStateManagerImplementationTests.swift
//  vpncore - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Clocks
@testable import CommonNetworking
import CommonNetworkingTestSupport
import Dependencies
import Domain
@testable import LegacyCommon
import Localization
@testable import VPNShared
import VPNSharedTesting
import XCTest

class AppStateManagerImplementationTests: XCTestCase {
    static let emptyError = NSError(domain: "ProtonVPNError", code: -1)

    let serverDescriptor = ServerDescriptor(username: "", address: "")
    let clock = TestClock()
    let alertService = CoreAlertServiceDummy()
    let networkingDelegate = FullNetworkingMockDelegate()

    var vpnManager: VpnManagerMock!
    var appStateManager: AppStateManager!

    override func setUp() {
        super.setUp()

        setUpNSCoding(withModuleName: "ProtonVPN")

        let networking = NetworkingMock()
        networking.delegate = networkingDelegate
        vpnManager = VpnManagerMock()

        let preparer = VpnManagerConfigurationPreparer(alertService: alertService)
        appStateManager = withDependencies {
            $0.continuousClock = clock
            $0.networking = VPNNetworkingMock()
            $0.vpnApiClient.clientCredentials = {
                VpnKeychainMock.vpnCredentials(planName: "plus", maxTier: .paidTier)
            }
            $0.vpnApiClient.sessionsCount = {
                SessionsResponse(sessionCount: 1)
            }
            $0.vpnApiClient.loads = { _ in
                [:]
            }
            $0.vpnApiClient.virtualServices = {
                VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:])
            }
            $0.vpnApiClient.refreshServerInfo = { _, _ in
                nil
            }
        } operation: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.hasConnected = true

            return AppStateManagerImplementation(
                vpnManager: vpnManager,
                alertService: alertService,
                configurationPreparer: preparer,
                vpnAuthentication: VpnAuthenticationMock()
            )
        }

        if case AppState.disconnected = appStateManager.state {} else { XCTFail("Wrong state") }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }

    override func tearDown() {
        super.tearDown()
        appStateManager.cancelConnectionAttempt()
    }

    func prepareToConnect() {
        appStateManager.prepareToConnect()
        let state = appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
    }

    func startConnection() {
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: connectionConfig)
        vpnManager.state = .connecting(serverDescriptor)

        let state = appStateManager.state
        if case AppState.connecting = state {} else {
            XCTFail("App state should be 'connecting' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func startConnectionFromConnected() {
        startExplicitDisconnectingAsPartOfConnect()
        successfullyDisconnectAsPartOfConnect()
        startConnection()
    }

    func successfullyConnect() {
        vpnManager.state = .connected(serverDescriptor)

        let state = appStateManager.state
        if case AppState.connected = state {} else {
            XCTFail("App state should be 'connected' but it's \(state.description)")
        }
        XCTAssert(state.isConnected)
        XCTAssertFalse(state.isDisconnected)
    }

    @MainActor
    func startDisconnecting() async {
        await execute(operation: {
            appStateManager.disconnect {}
            vpnManager.state = .disconnecting(serverDescriptor)
        }, expectingAppStateTransitionTo: { appState in
            guard case .disconnecting = appState else {
                return false
            }
            return true
        })
    }

    @MainActor
    func successfullyDisconnect() async {
        await execute(operation: {
            vpnManager.state = .disconnected
        }, expectingAppStateTransitionTo: { appState in
            guard case .disconnected = appState else {
                return false
            }
            return true
        })
    }

    func startExplicitDisconnectingAsPartOfConnect() {
        appStateManager.disconnect()
        vpnManager.state = .disconnecting(serverDescriptor)

        let state = appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func startImplicitDisconnectingAsPartOfConnect() {
        vpnManager.state = .disconnecting(serverDescriptor)

        let state = appStateManager.state
        if case AppState.connecting = state {} else {
            XCTFail("App state should be 'connecting' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func successfullyDisconnectAsPartOfConnect() {
        vpnManager.state = .disconnected

        let state = appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func userInitatedCancel() {
        appStateManager.cancelConnectionAttempt()

        let state = appStateManager.state
        if case let AppState.aborted(userInitiated) = state {
            XCTAssert(userInitiated)
        } else { XCTFail("Wrong state") }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func initialError() {
        vpnManager.state = .error(Self.emptyError)

        let state = appStateManager.state
        if case AppState.disconnected = state {} else {
            XCTFail("App state should be 'disconnected' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func subsequentError() {
        vpnManager.state = .error(Self.emptyError)

        let state = appStateManager.state
        if case AppState.error = state {} else {
            XCTFail("App state should be 'error' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func testConnectionFromInvalidOrDisconnected() {
        prepareToConnect()
        startConnection()
        successfullyConnect()
    }

    @MainActor
    func testDisconnectionFromConnected() async {
        testConnectionFromInvalidOrDisconnected()
        await startDisconnecting()
        await successfullyDisconnect()
    }

    @MainActor
    func testConnectionFromConnected() async {
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        await successfullyConnect()
    }

    @MainActor
    func testDisconnectionFromDisconnected() async {
        await successfullyDisconnect()
        await startDisconnecting()
        await successfullyDisconnect()
    }

    @MainActor
    func testDisconnectDuringConnectingFromConnected() async {
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        startImplicitDisconnectingAsPartOfConnect()
        await successfullyDisconnect()
    }

    func testCancelConnecting() {
        prepareToConnect()
        startConnection()
        userInitatedCancel()

        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        userInitatedCancel()
    }

    @MainActor
    private func execute(
        operation: () async -> Void,
        expectingAppStateTransitionTo appStateMatches: @escaping (AppState) -> Bool,
        timeout: TimeInterval = 1
    ) async {
        let doesNotificationMatchAppState: XCTNSNotificationExpectation.Handler = { notification in
            guard let appState = notification.object as? AppState else {
                return false
            }
            print("App state change \(appState)")
            return appStateMatches(appState)
        }

        let expectation = XCTNSNotificationExpectation(name: AppEvent.appStateManagerStateChange.name)
        expectation.handler = doesNotificationMatchAppState
        await operation()
        await fulfillment(of: [expectation], timeout: timeout)
    }

    @MainActor
    func testTimedOutConnecting() async {
        prepareToConnect()
        startConnection()

        await clock.advance(by: .seconds(35))
        await startDisconnecting()
        await successfullyDisconnect()

        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()

        await clock.advance(by: .seconds(35))
        await startDisconnecting()
        await successfullyDisconnect()
    }

    func testErrorConnecting() {
        prepareToConnect()
        startConnection()
        subsequentError()

        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        subsequentError()
    }

    func testReasserting() {
        vpnManager.state = .connecting(serverDescriptor)
        vpnManager.state = .reasserting(serverDescriptor)

        let state = appStateManager.state
        if case AppState.connecting = state {} else {
            XCTFail("State should be 'connecting' but is actually \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }

    func testSupressesInitialError() {
        initialError()
        subsequentError()
    }

    func testConnectingWithEmptyPortsFails() {
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(
            withConfiguration: ConnectionConfiguration(
                id: connectionConfig.id,
                server: connectionConfig.server,
                serverIp: connectionConfig.serverIp,
                vpnProtocol: connectionConfig.vpnProtocol,
                netShieldType: connectionConfig.netShieldType,
                natType: connectionConfig.natType,
                safeMode: connectionConfig.safeMode,
                portForwarding: connectionConfig.portForwarding,
                ports: [],
                intent: connectionConfig.intent
            )
        )

        let state = appStateManager.state
        if case AppState.error = state {} else {
            XCTFail("App state should be 'error' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isDisconnected)
    }

    lazy var connectionConfig: ConnectionConfiguration = {
        let server = ServerModel(id: "", name: "", domain: "", load: 0, entryCountryCode: "", exitCountryCode: "", tier: 1, feature: .zero, city: nil, ips: [ServerIp](), score: 0.0, status: 0, location: ServerLocation(lat: 0, long: 0), hostCountry: nil, translatedCity: nil, gatewayName: nil)
        let serverIp = ServerIp(id: "", entryIp: "", exitIp: "", domain: "", status: 0)
        return ConnectionConfiguration(
            id: UUID(),
            server: server,
            serverIp: serverIp,
            vpnProtocol: .ike,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            portForwarding: true,
            ports: [500],
            intent: .fastest
        )
    }()
}
