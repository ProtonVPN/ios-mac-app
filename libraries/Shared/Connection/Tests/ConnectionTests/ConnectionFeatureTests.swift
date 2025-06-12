//
//  Created on 25/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

#if targetEnvironment(simulator) // MockTunnelManager is only built for the simulator
    import XCTest
    import NetworkExtension
    import ComposableArchitecture

    import Domain
    import DomainTestSupport
    import Ergonomics
    import VPNShared
    import VPNSharedTesting

    @testable import CoreConnection
    import CoreConnectionTestSupport
    @testable import ExtensionManager
    @testable import CertificateAuthentication
    @testable import LocalAgent
    @testable import Connection
    import ConnectionTestSupport

    final class ConnectionFeatureTests: XCTestCase {
        /// Verifies that a connection can be queued up if the feature is in the disconnecting state and the user
        /// attempts to connect somewhere, as well as both internal and external state changes as expected.
        /// e.g. during reconnection, external state transitions to `.connecting`, skipping `.disconnected`.
        @MainActor func testStartingConnectionWhileDisconnecting() async {
            let mockVPNSession = VPNSessionMock(status: .disconnecting, connectedDate: nil, lastDisconnectError: nil)
            let mockManager = MockTunnelManager(connection: mockVPNSession)
            let mockClock = TestClock()
            let mockAgent = LocalAgentMock(state: .disconnected)

            let now = Date.now
            let tomorrow = now.addingTimeInterval(.days(1))
            let portSelectionExpectation = XCTestExpectation(description: "Port selector should be invoked")

            let mockStorage = MockVpnAuthenticationStorage()
            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            mockStorage.keys = keys
            mockStorage.cert = certificate

            let connectionFeatures: VPNConnectionFeatures = .mock
            let server = Server.ca
            let reconnectingServerInfo = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)
            let initialIntent = ServerConnectionIntent.mock()
            let reconnectionSpec = ConnectionSpec(location: .region(code: "CA"), features: [])
            let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec, server: server)
            let preparedReconnectionIntent = ServerConnectionIntent.mock(
                withSpecLocation: .region(code: "CA"),
                server: server,
                tunnelSettings: .init(transport: .tls, ports: [420], features: .unimplementedFeatures),
                features: connectionFeatures
            )

            let coreState = CoreConnectionFeature.State(
                tunnelState: .disconnecting(nil),
                certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: keys), certificate: certificate, features: connectionFeatures)),
                localAgentState: .disconnected(nil)
            )

            let initialState = ConnectionFeature.State(
                currentIntent: initialIntent,
                queuedIntent: nil,
                connectionState: .resolving,
                shouldRegisterServerChangeOnConnection: false,
                core: coreState
            )
            initialState.$userTier = SharedReader(value: .paidTier)

            let store = TestStore(initialState: initialState) {
                ConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.certificateRefreshClient = .init(refreshCertificate: { _ in .ok }, pushSelector: {})
                $0.vpnAuthenticationStorage = mockStorage
                $0.localAgent = mockAgent
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.connectionIntentStorage = .init(getConnectionIntent: { initialIntent }, set: { _ in })
                $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
                $0.smartPortSelector.select = { _, _ in
                    portSelectionExpectation.fulfill()
                    return ServerEndpointPortResolution(chosenProtocol: .wireGuard(.tls), ports: [420])
                }
                $0.defaultAppStorage = .testValue()
            }

            await store.send(.input(.onLaunch))
            await store.receive(\.core.startObserving)
            await store.receive(\.core.tunnel.startObservingStateChanges)
            await store.receive(\.core.localAgent.startObservingEvents)
            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnecting)

            // Connection feature is in the 'disconnecting' state, now let's send a connection request
            await store.send(.input(.connect(reconnectionPreparationIntent))) {
                $0.reconnectionIntent = reconnectionPreparationIntent
                $0.connectionState = .connecting(.unresolved(reconnectionPreparationIntent))
            }
            await store.receive(stateChange(to: \.connecting.unresolved))

            mockVPNSession.status = .disconnected // Simulate the disconnection attempt finishing
            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnected) {
                $0.core.tunnel = .disconnected(nil)
            }
            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected)) {
                $0.reconnectionIntent = nil
            }

            // Now that we are fully disconnected, the queued connection attempts should immediately start
            await store.receive(\.prepare)
            await store.receive(\.finishedPreparing.success) {
                $0.currentIntent = preparedReconnectionIntent
                $0.connectionState = .connecting(.resolved(preparedReconnectionIntent, server))
            }
            await store.receive(stateChange(to: \.connecting.resolved))

            await fulfillment(of: [portSelectionExpectation], timeout: 0) // Let's verify port selection occurred before connection
            await store.receive(\.core.connect)
            await store.receive(\.core.tunnel.connect) {
                $0.core.tunnel = .preparingConnection(reconnectingServerInfo)
            }
            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.core.tunnel.tunnelStartRequestFinished.success)
            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting) {
                $0.core.tunnel = .connecting(reconnectingServerInfo)
            }

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.core.tunnel.tunnelStatusChanged.connected)
            await store.receive(\.core.tunnel.connectionFinished.success) {
                $0.core.tunnel = .connected(TunnelConnectionResponse(logicalInfo: reconnectingServerInfo, connectionDate: now))
            }
            await store.receive(coreStateChange(from: \.starting, to: \.connecting))

            await store.receive(\.core.certAuth.loadAuthenticationData)
            await store.receive(\.core.certAuth.loadingFinished.success)
            await store.receive(\.core.localAgent.connect)
            await store.receive(\.core.localAgent.startNetShieldStatsObservation)
            await store.receive(\.core.localAgent.event.state.connecting) {
                $0.core.localAgent = .connecting(nil)
            }

            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
            await store.receive(\.core.localAgent.event.state.connected) {
                $0.core.localAgent = .connected(nil)
            }
            await store.receive(coreStateChange(from: \.connecting, to: \.connected)) {
                $0.connectionState = .connected(preparedReconnectionIntent, server, now, nil)
            }
            await store.receive(stateChange(to: \.connected))

            await store.send(.stopObserving)
            await store.receive(\.core.stopObserving)
            await store.receive(\.core.tunnel.stopObservingStateChanges)
            await store.receive(\.core.localAgent.stopAllObservations)
        }

        /// Verifies that a connection can be queued up if the feature is in the connected state already, as well as
        /// both internal and external state changes as expected.
        /// e.g. during reconnection, external state transitions to `.connecting`, skipping `.disconnected`.
        @MainActor func testStartingConnectionWhileConnectedResultsInReconnection() async {
            let now = Date.now
            let tomorrow = now.addingTimeInterval(.days(1))
            let portSelectionExpectation = XCTestExpectation(description: "Port selector should be invoked")

            let mockVPNSession = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
            let mockManager = MockTunnelManager(connection: mockVPNSession)
            let mockClock = TestClock()
            let mockAgent = LocalAgentMock(state: .disconnected)

            let mockStorage = MockVpnAuthenticationStorage()
            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            mockStorage.keys = keys
            mockStorage.cert = certificate

            let connectionFeatures: VPNConnectionFeatures = .mock
            let initialServerInfo = LogicalServerInfo(logicalID: Server.mock.logical.id, serverID: Server.mock.endpoint.id)
            let initialIntent = ServerConnectionIntent.mock()

            let serverToReconnectTo = Server.ca
            let reconnectionSpec = ConnectionSpec(location: .region(code: "CA"), features: [])
            let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec, server: serverToReconnectTo)
            let preparedReconnectionIntent = ServerConnectionIntent.mock(
                withSpecLocation: .region(code: "CA"),
                server: serverToReconnectTo,
                tunnelSettings: .init(transport: .tls, ports: [420], features: .unimplementedFeatures),
                features: connectionFeatures
            )

            // Because of the initial value we observe in `ExtensionFeature.Action.startObservingStateChanges`, we can't fully
            // accurately model starting a reducer in the fully connected state yet.
            // It's not a problem, since we always start from the resolving state when running in the app.
            let coreState = CoreConnectionFeature.State(
                tunnelState: .connecting(initialServerInfo),
                certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: keys), certificate: certificate, features: connectionFeatures)),
                localAgentState: .disconnected(nil)
            )

            let initialState = ConnectionFeature.State(
                currentIntent: initialIntent,
                queuedIntent: nil,
                connectionState: .resolving,
                shouldRegisterServerChangeOnConnection: false,
                core: coreState
            )
            initialState.$userTier = SharedReader(value: .paidTier)

            let store = TestStore(initialState: initialState) {
                ConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.certificateRefreshClient = .init(refreshCertificate: { _ in .ok }, pushSelector: {})
                $0.vpnAuthenticationStorage = mockStorage
                $0.localAgent = mockAgent
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.connectionIntentStorage = .init(getConnectionIntent: { initialIntent }, set: { _ in })
                $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
                $0.smartPortSelector.select = { _, _ in
                    portSelectionExpectation.fulfill()
                    return ServerEndpointPortResolution(chosenProtocol: .wireGuard(.tls), ports: [420])
                }
                $0.defaultAppStorage = .testValue()
            }

            // Let's skip repeating assertions we've covered in previous tests
            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await mockClock.advance(by: .seconds(2))
            await store.receive(stateChange(to: \.connected))

            // Connection feature is in the 'connected' state, now let's send a connection request
            await store.send(.input(.connect(reconnectionPreparationIntent))) {
                $0.reconnectionIntent = reconnectionPreparationIntent
            }
            await store.receive(\.core.disconnect)
            await mockClock.advance(by: .seconds(1))
            await store.receive(coreStateChange(from: \.connected, to: \.disconnecting))
            await store.receive(stateChange(to: \.connecting))
            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected))

            // We've finally disconnected, so it's now sensible to start port/protocol selection
            // Now that we are fully disconnected, the queued connection attempts should immediately start
            await store.receive(\.prepare)
            await store.receive(\.finishedPreparing) {
                $0.currentIntent = preparedReconnectionIntent
            }

            await fulfillment(of: [portSelectionExpectation], timeout: 0)
            await store.receive(\.core.connect)
            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
            await mockClock.advance(by: .seconds(1)) // Give LocalAgent time to connect
            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
            await store.receive(stateChange(to: \.connected))
        }

        @MainActor func testDisconnectDuringPreparationCancelsConnection() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .mock)

            store.dependencies.connectionIntentResolver = .init(resolve: { intent in
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: .seconds(2))
                try Task.checkCancellation()
                XCTFail("Preparation should have been cancelled")
                return .mock()
            }, authorize: { _, _ in
            })

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(preparationIntent)))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved)) {
                $0.connectionState = .connecting(.unresolved(preparationIntent))
            }

            await environment.clock.advance(by: .seconds(1))

            await store.send(.input(.disconnect))

            await environment.clock.advance(by: .seconds(1))

            await store.receive(stateChange(to: \.disconnected)) {
                $0.connectionState = .disconnected
            }
        }

        /// Connection preparation must be completed while disconnected from the VPN.
        /// Upon finishing preparation, if we find that the core connection state is not disconnected, the tunnel has
        /// likely been started externally, and we cannot guarantee that the feature is ready to handle the connection
        /// attempt, so it should be disconnected with an error.
        @MainActor func testExternalConnectionDuringPreparationHandledByDisconnectingWithError() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            store.dependencies.connectionIntentStorage = .init(getConnectionIntent: { .mock() }, set: { _ in })
            store.dependencies.smartPortSelector = .init(select: { endpoint, proto in
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: .seconds(2))
                return .init(chosenProtocol: .wireGuard(.udp), ports: [1337])
            })

            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .mock)

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(preparationIntent)))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved)) {
                $0.connectionState = .connecting(.unresolved(preparationIntent))
            }

            // Give some time for preparation to start
            await environment.clock.advance(by: .seconds(1))

            // Halfway during preparation, the tunnel is started either by the system due to on-demand rules, or by the
            // user from the control centre (they must be fast because preparation is only ~1s long!)
            environment.vpnSession.status = .connecting
            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting)
            await store.receive(stateChange(to: \.connecting.resolved))

            // Advance the clock so that preparation finishes
            await environment.clock.advance(by: .seconds(1))
            await store.receive(\.finishedPreparing.success)
            await store.receive(\.core.disconnect.connectionFailure.preparation.featureNotReady)
            await store.receive(\.delegate.connectionFailed.preparation.featureNotReady)
            await store.receive(stateChange(to: \.disconnecting))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnected)) {
                $0.connectionState = .disconnected
            }
        }

        @MainActor func testFeatureDelaysInternalDisconnectWhenStartingTunnelUntilTunnelStartSucceeds() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()
            store.exhaustivity = .off

            // Let's manually model what tunnel state transitions.
            environment.vpnSession.startupDuration = nil
            environment.vpnSession.connectionDuration = nil
            environment.vpnSession.disconnectionDuration = nil

            // Let's make sure tunnel stop is not called too early
            environment.tunnelManager.didStopTunnelCallback = { XCTFail("Tunnel was stopped too early") }

            let server = Server.mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .mock)

            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            // Connection
            await store.send(.input(.connect(preparationIntent)))

            await store.receive(\.core.tunnel.connect) {
                $0.core.tunnel = .preparingConnection(connectedLogicalServer)
            }

            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.core.tunnel.tunnelStartRequestFinished.success)

            environment.vpnSession.status = .connecting // Sends a `NEVPNStatusDidChange` notification
            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting) {
                $0.core.tunnel = .connecting(connectedLogicalServer)
            }

            // The extension has started, but must not be interrupted until it is connected.
            // If the user cancels the connection, we *must not* send a `tunnel.disconnect` action until the tunnel is
            // either in the `connected` or `disconnected` state

            await store.send(.input(.disconnect))
            await store.receive(stateChange(to: \.disconnecting))

            let tunnelStopInvoked = XCTestExpectation(description: "Tunnel stop should have been requested")
            environment.tunnelManager.didStopTunnelCallback = { tunnelStopInvoked.fulfill() }
            environment.vpnSession.status = .connected // Sends a `NEVPNStatusDidChange` notification

            await store.receive(\.core.tunnel.tunnelStatusChanged.connected)
            await store.receive(\.core.tunnel.connectionFinished.success)
            await store.receive(coreStateChange(from: \.starting, to: \.connecting))

            // Finally, the tunnel is ready to be stopped, and we should proceed with the disconnection
            await store.receive(\.core.disconnect)
            await store.receive(\.core.localAgent.disconnect)
            await store.receive(\.core.tunnel.disconnect)
            await store.receive(coreStateChange(from: \.connecting, to: \.disconnecting))

            await fulfillment(of: [tunnelStopInvoked], timeout: 0)
            environment.vpnSession.status = .disconnected
            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnected)
            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected))
            await store.receive(stateChange(to: \.disconnected))
            await store.send(.stopObserving)
        }

        @MainActor func testConnectionStateResolvesToDisconnected() async {
            let mockVPNSession = VPNSessionMock(status: .disconnected, connectedDate: nil, lastDisconnectError: nil)
            let mockManager = MockTunnelManager(connection: mockVPNSession)
            let mockAgent = LocalAgentMock(state: .disconnected)

            let store = TestStore(initialState: .initialState) {
                ConnectionFeature()
            } withDependencies: {
                $0.tunnelManager = mockManager
                $0.localAgent = mockAgent
            }

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(coreStateChange(from: \.unknown, to: \.disconnected))
            await store.receive(stateChange(to: \.disconnected))
        }

        @MainActor func testConnectionStateResolvesToConnected() async {
            let now = Date.now
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockClock = TestClock()
            let mockVPNSession = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
            let mockManager = MockTunnelManager(connection: mockVPNSession)
            let mockAgent = LocalAgentMock(state: .disconnected)

            let mockStorage = MockVpnAuthenticationStorage()
            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            mockStorage.keys = keys
            mockStorage.cert = certificate
            mockStorage.features = .mock

            let store = TestStore(initialState: .initialState) {
                ConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.localAgent = mockAgent
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
                $0.vpnAuthenticationStorage = mockStorage
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.connectionIntentStorage = .init(getConnectionIntent: { .mock() }, set: { _ in })
            }

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await mockClock.advance(by: .seconds(2))
            await store.receive(coreStateChange(from: \.unknown, to: \.starting))
            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
            await store.receive(stateChange(to: \.connected))
        }

        @MainActor func testFeatureSendsDelegateActionWhenPreparationFails() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up a failure that should happen during connection preparation
            let preparationError = ConnectionError.unexpectedProtocol(.ike)
            store.dependencies.connectionIntentResolver = .init(resolve: { _ in
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: .seconds(1))
                throw preparationError
            }, authorize: { _, _ in
            })

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved))

            await environment.clock.advance(by: .seconds(1))

            await store.receive(\.finishedPreparing.failure)
            await store.receive(stateChange(to: \.disconnected))
            await store.receive(\.delegate.connectionFailed.preparation)
        }

        @MainActor func testFeatureSendsDelegateActionWhenAuthorizerThrows() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up a failure that should happen during connection preparation
            store.dependencies.connectionIntentResolver = .init(resolve: { _ in
                XCTFail("Shouldn't get to preparation step, authorization should fail first")
                return .mock()
            }, authorize: { _, _ throws (ConnectionIntentResolutionError) in
                throw ConnectionIntentResolutionError.specificCountryUnavailable(countryCode: "US")
            })

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive { action in
                guard case let .delegate(.intentResolutionFailed(_, error)) = action,
                      case let .specificCountryUnavailable(countryCode) = error,
                      countryCode == "US" else {
                    return false
                }
                return true
            }
        }

        @MainActor func testFeatureSendsDelegateActionWhenTunnelStartFails() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up a failure to occur while starting the tunnel
            let tunnelStartError = NSError(domain: NEVPNErrorDomain, code: 4)
            environment.tunnelManager.tunnelStartErrorToThrow = tunnelStartError

            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .ca)

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(preparationIntent)))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved)) { $0.connectionState = .connecting(.unresolved(preparationIntent)) }
            await store.receive(\.finishedPreparing.success)
            await store.receive(stateChange(to: \.connecting.resolved))
            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(coreStateChange(from: \.starting, to: \.disconnected))
            await store.receive(stateChange(to: \.disconnected))
            await store.receive(\.delegate.connectionFailed.tunnel.tunnelStartFailed)

            await store.send(.stopObserving)
        }

        @MainActor func testFeatureSendsDelegateActionWhenCertAuthFails() async {
            let environment = ConnectionEnvironment.disconnected(certificateState: .expired)
            let store = environment.createConnectionTestStore()

            // Set up a failure to occur while refreshing our certificate
            let certRefreshResult = CertificateRefreshResult.ipcError(message: "No data received")
            store.dependencies.certificateRefreshClient.refreshCertificate = { _ in certRefreshResult }

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(stateChange(to: \.connecting.unresolved))
            await store.receive(stateChange(to: \.connecting.resolved))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnecting))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnected))
            await store.receive(\.delegate.connectionFailed.certAuth.ipc)
        }

        @MainActor func testFeatureSendsDelegateActionWhenLocalAgentConnectionCreationFails() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up a failure to occur while creating the local agent connection
            let localAgentError: LAConnectionCreationError = .goTLSError(.privateKeyDoesNotMatchPublicKey, underlyingError: "" as GenericError)
            environment.localAgent.connectionErrorToThrow = localAgentError

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(stateChange(to: \.connecting.unresolved))
            await store.receive(stateChange(to: \.connecting.resolved))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnecting))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnected))
            await store.receive(\.delegate.connectionFailed.agent.failedToEstablishConnection)
        }

        @MainActor func testFeatureSendsDelegateActionWhenConnectionTimesOut() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up local agent to take longer to connect than the timeout limit of 30 seconds
            environment.localAgent.connectionDuration = .seconds(60)

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(stateChange(to: \.connecting.unresolved))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.connecting.resolved))

            await environment.clock.advance(by: .seconds(29))
            await store.receive(\.delegate.connectionFailed.timeout)
            await store.receive(stateChange(to: \.disconnecting))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnected))
        }

        @MainActor func testFeatureCancelsFirstPreparationWhenSecondConnectionRequested() async {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            let canadaSpec = ConnectionSpec(location: .region(code: "CA"), features: [])
            let firstIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .mock)
            let secondIntent = ConnectionPreparationIntent(spec: canadaSpec, server: .ca)

            let expectedResolvedIntent = ServerConnectionIntent(spec: canadaSpec, server: .ca, tunnelSettings: .mock, features: .mock)

            store.dependencies.connectionIntentResolver = .init(resolve: { intent in
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: .seconds(2))
                return .init(spec: intent.spec, server: intent.server, tunnelSettings: .mock, features: .mock)
            }, authorize: { _, _ in
            })

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(firstIntent)))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved)) {
                $0.connectionState = .connecting(.unresolved(firstIntent))
            }

            await environment.clock.advance(by: .seconds(1)) // preparation effect should be in-flight

            await store.send(.input(.connect(secondIntent)))
            await store.receive(stateChange(to: \.connecting.unresolved)) {
                $0.connectionState = .connecting(.unresolved(secondIntent))
            }

            await environment.clock.advance(by: .seconds(2)) // second effect should finish
            await store.receive(\.finishedPreparing.success)
            await store.receive(stateChange(to: \.connecting.resolved)) {
                // Assert that the second effect finished, not the first
                $0.connectionState = .connecting(.resolved(expectedResolvedIntent, .ca))
            }
        }

        /// Tests that after failing to connect, the next successful connection attempt transitions through all expected states.
        @MainActor func testFeatureStateTransitionsOnSecondConnectionAfterFirstFailedConnection() async throws {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up a failure that should happen during tunnel start
            let entryUnavailableError = WireguardConfiguratorError.entryUnavailableForTransport(.udp)
            environment.tunnelManager.tunnelStartErrorToThrow = ConnectionError.tunnel(.tunnelStartFailed(entryUnavailableError))

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved))

            await store.receive(\.finishedPreparing.success)
            await store.receive(stateChange(to: \.connecting.resolved))

            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
            await store.receive(coreStateChange(from: \.starting, to: \.disconnected))

            await store.receive(stateChange(to: \.disconnected))
            await store.receive(\.delegate.connectionFailed.tunnel.tunnelStartFailed)

            // This time, connection should succeed
            environment.tunnelManager.tunnelStartErrorToThrow = nil

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(\.prepare)
            await store.receive(stateChange(to: \.connecting.unresolved))

            await store.receive(\.finishedPreparing.success)
            await store.receive(stateChange(to: \.connecting.resolved))

            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(coreStateChange(from: \.starting, to: \.connecting))

            await environment.clock.advance(by: .seconds(1))
            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
            await store.receive(stateChange(to: \.connected))
        }

        @MainActor func testConnectionTimesOutIfNeverUnjailedByRestrictedServer() async throws {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()
            environment.localAgent.connectionResult = .init(state: .hardJailed, error: .restrictedServer)

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(stateChange(to: \.connecting.unresolved))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.connecting.resolved))
            await environment.clock.advance(by: .seconds(1))

            // When connecting to a restricted server, we are hardjailed and must wait until it can verify our certificate
            // has not been revoked
            await store.receive(\.core.localAgent.event.error.restrictedServer)
            await environment.clock.advance(by: .seconds(28))

            // The server failed to authenticate us in time, so we should time out
            await store.receive(\.delegate.connectionFailed.timeout)
            await store.receive(stateChange(to: \.disconnecting))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.disconnected))
        }

        @MainActor func testConnectionSucceedsOnceUnjailedByRestrictedServer() async throws {
            let environment = ConnectionEnvironment.disconnected()
            let store = environment.createConnectionTestStore()

            // Set up local agent to take longer to connect than the timeout limit of 30 seconds
            environment.localAgent.connectionResult = .init(state: .hardJailed, error: .restrictedServer)

            store.exhaustivity = .off
            await store.send(.input(.onLaunch))
            await store.receive(stateChange(to: \.disconnected))

            await store.send(.input(.connect(.init(spec: .defaultFastest, server: .ca))))
            await store.receive(stateChange(to: \.connecting.unresolved))
            await environment.clock.advance(by: .seconds(1))
            await store.receive(stateChange(to: \.connecting.resolved))
            await environment.clock.advance(by: .seconds(1))

            // When connecting to a restricted server, we are hardjailed and must wait until it can verify our certificate
            // has not been revoked
            await store.receive(\.core.localAgent.event.error.restrictedServer)
            await environment.clock.advance(by: .seconds(13))
            environment.localAgent.simulate(event: .state(.connected))

            await store.receive(stateChange(to: \.connected))

            // Let's fast forward to when we would have timed out, had the server not unjailed us
            await environment.clock.advance(by: .seconds(15))
        }

        private func stateChange(
            to expectedState: PartialCaseKeyPath<ConnectionState>,
            strict: Bool = true
        ) -> (ConnectionFeature.Action) -> Bool {
            return { action in
                guard case let .delegate(.stateChanged(state)) = action else {
                    return false
                }
                if state.is(expectedState) {
                    return true
                }
                if strict {
                    XCTFail("Received state change action, but to the incorrect state (\(caseName(of: state)))")
                }
                return false
            }
        }

        private func coreStateChange(
            from oldValue: PartialCaseKeyPath<CoreConnectionState>,
            to newValue: PartialCaseKeyPath<CoreConnectionState>,
            strict: Bool = true
        ) -> (ConnectionFeature.Action) -> Bool {
            return stateChangePredicate(
                from: oldValue,
                to: newValue,
                extract: \ConnectionFeature.Action.[case: \.core.delegate.stateChanged],
                strict: strict
            )
        }
    }

    fileprivate func caseName(of value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        return String(describing: mirror.children.first?.label ?? "\(value)")
    }
#endif
