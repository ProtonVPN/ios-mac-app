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

#if DEBUG // MockTunnelManager is only built for the simulator
    import ComposableArchitecture
    @testable import Connection
    import ConnectionTestSupport
    @testable import CoreConnection
    import CoreConnectionTestSupport
    import Domain
    import DomainTestSupport
    import Ergonomics
    @testable import ExtensionManager
    import Network
    import NetworkExtension
    import Testing
    import VPNShared
    import VPNSharedTesting
    import XCTest

    #if !os(tvOS)
        struct ConnectionFeatureTransitionTests {
            /// Disconnecting with Advanced kill switch Active (the live tunnel was armed at connect) switches to
            /// zero-peer blocking in place, reflected in the state immediately.
            @Test
            @MainActor
            func disconnectWithActiveAdvancedKillSwitchSwitchesToZeroPeerInPlace() async {
                let spec = ConnectionSpec(location: .country(code: "IT", order: .fastest), features: [])
                let configuration = TunnelConfiguration(
                    connectionSpec: spec,
                    tunnelProtocol: .wireGuard,
                    peerIDs: ["old-peer"],
                    killSwitch: true
                )
                let session = VPNSessionMock(status: .connected)
                session.messageHandler = MessageHandler.full
                @Shared(.connectionState) var connectionState
                $connectionState.withLock {
                    $0 = .connected(
                        configuration,
                        .init(
                            currentPeer: .mock,
                            connectionDate: .now,
                            protocolConnectionData: .proTUN(.init(transport: .udp))
                        )
                    )
                }
                let store = TestStore(initialState: ConnectionFeature.State(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .unknown
                )) {
                    ConnectionFeature()
                } withDependencies: {
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: {
                            #if !os(tvOS)
                                .init(killSwitchMode: .advanced, excludeLocalNetworks: false)
                            #else
                                .tvFeatures
                            #endif
                        },
                        connectionProtocol: { .smartProtocol }
                    )
                    $0.tunnelManager = MockTunnelManager(connection: session)
                }
                store.exhaustivity = .off

                await store.send(.input(.disconnect)) {
                    $0.isBlockingIntended = true
                }
                // The zero-peer switch goes to the extension as a config change. The connection state
                // keeps reporting the tunnel as connected and only becomes `.killSwitchActive` once the
                // extension confirms the applied request.
                await store.receive(\.tunnel.requestConfigChange)
                #expect(store.state.connectionState.is(\.connected))
            }

            /// The projection rebuilds the tunnel configuration to resolve the spec, and it must carry the
            /// kill switch flag along. The disconnect handler decides between blocking and releasing based
            /// on the projected value, so losing the flag here silently downgrades Advanced kill switch.
            @Test
            @MainActor
            func projectionPreservesKillSwitchFlag() async {
                let armedConfiguration = TunnelConfiguration(
                    connectionSpec: ConnectionSpec(location: .country(code: "IT", order: .fastest), features: []),
                    tunnelProtocol: .wireGuard,
                    peerIDs: ["peer-id"],
                    killSwitch: true
                )
                let store = TestStore(initialState: ConnectionFeature.State(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .unknown
                )) {
                    ConnectionFeature()
                } withDependencies: {
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: {
                            #if !os(tvOS)
                                .init(killSwitchMode: .advanced, excludeLocalNetworks: false)
                            #else
                                .tvFeatures
                            #endif
                        },
                        connectionProtocol: { .smartProtocol }
                    )
                    $0.serverIdentifier = .init(fullServerInfo: { _ in .ca })
                    $0.defaultAppStorage = .testValue()
                }
                store.exhaustivity = .off

                await store.send(.tunnel(.tunnelStatusChanged(.connected(
                    armedConfiguration,
                    DynamicConnectionData(
                        currentPeerId: "peer-id",
                        connectionDate: .now,
                        protocolConnectionData: .proTUN(.init(transport: .udp))
                    )
                ))))
                #expect(store.state.connectionState.tunnelKillSwitch)
            }

            /// Disconnecting with Standard kill switch releases the tunnel instead of blackholing: the state is
            /// left for projection to walk down, and no zero-peer switch happens.
            @Test
            @MainActor
            func disconnectWithStandardKillSwitchReleasesTunnel() async {
                let spec = ConnectionSpec(location: .country(code: "IT", order: .fastest), features: [])
                let configuration = TunnelConfiguration(
                    connectionSpec: spec,
                    tunnelProtocol: .wireGuard,
                    peerIDs: ["old-peer"],
                    killSwitch: true
                )
                let session = VPNSessionMock(status: .connected)
                session.messageHandler = MessageHandler.full
                @Shared(.connectionState) var connectionState
                $connectionState.withLock {
                    $0 = .connected(
                        configuration,
                        .init(
                            currentPeer: .mock,
                            connectionDate: .now,
                            protocolConnectionData: .proTUN(.init(transport: .udp))
                        )
                    )
                }
                let store = TestStore(initialState: ConnectionFeature.State(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .unknown
                )) {
                    ConnectionFeature()
                } withDependencies: {
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: {
                            #if !os(tvOS)
                                .init(killSwitchMode: .standard, excludeLocalNetworks: false)
                            #else
                                .tvFeatures
                            #endif
                        },
                        connectionProtocol: { .smartProtocol }
                    )
                    $0.tunnelManager = MockTunnelManager(connection: session)
                    $0.continuousClock = TestClock()
                }
                store.exhaustivity = .off

                await store.send(.input(.disconnect))
                #expect(store.state.connectionState.is(\.connected))
            }

            /// A disconnect request while zero-peer blocking is active (e.g. sent by the widget) must
            /// not tear down the blackhole as long as the mode stays Advanced. Only leaving Advanced
            /// releases it, via this same action sent after the mode change. The store is exhaustive,
            /// so the test fails if the disconnect starts mutating state or emitting effects.
            @Test
            @MainActor
            func disconnectWhileBlockingUnderAdvancedKeepsTheBlackhole() async {
                let spec = ConnectionSpec(location: .country(code: "IT", order: .fastest), features: [])
                let zeroPeerConfiguration = TunnelConfiguration(
                    connectionSpec: spec,
                    tunnelProtocol: .wireGuard,
                    peerIDs: [],
                    killSwitch: true
                )
                @Shared(.connectionState) var connectionState
                $connectionState.withLock {
                    $0 = .killSwitchActive(spec, zeroPeerConfiguration)
                }
                let store = TestStore(initialState: ConnectionFeature.State(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .killSwitchActive(zeroPeerConfiguration)
                )) {
                    ConnectionFeature()
                } withDependencies: {
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: { .init(killSwitchMode: .advanced, excludeLocalNetworks: false) },
                        connectionProtocol: { .smartProtocol }
                    )
                }

                await store.send(.input(.disconnect))
            }

            /// An unexpected drop while Advanced kill switch is blocking (or armed) cold-starts a fresh
            /// zero-peer tunnel, and the disconnect error is deliberately swallowed: reporting
            /// `.delegate(.connectionFailed)` would invite failure handling while the protection is
            /// being restored. The store is exhaustive, so the test fails if the handler starts
            /// emitting the failure delegate (or anything else) alongside the restart.
            @Test
            @MainActor
            func unexpectedDropWithAdvancedKillSwitchColdStartsBlockingWithoutReportingFailure() async {
                let spec = ConnectionSpec(location: .country(code: "IT", order: .fastest), features: [])
                let configuration = TunnelConfiguration(
                    connectionSpec: spec,
                    tunnelProtocol: .wireGuard,
                    peerIDs: ["old-peer"],
                    killSwitch: true
                )
                let connectionData = DynamicConnectionData(
                    currentPeerId: "old-peer",
                    connectionDate: .now,
                    protocolConnectionData: .proTUN(.init(transport: .udp))
                )
                var initialState = ConnectionFeature.State(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .connected(configuration, connectionData)
                )
                initialState.isBlockingIntended = true
                // A nil startup duration stops the session mock right after the start request, so no
                // detached status-transition task outlives this test and pollutes parallel suites.
                let session = VPNSessionMock(status: .disconnected)
                session.startupDuration = nil
                @Shared(.connectionState) var connectionState
                $connectionState.withLock {
                    $0 = .connected(
                        configuration,
                        .init(
                            currentPeer: .mock,
                            connectionDate: .now,
                            protocolConnectionData: .proTUN(.init(transport: .udp))
                        )
                    )
                }
                let store = TestStore(initialState: initialState) {
                    ConnectionFeature()
                } withDependencies: {
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: { .init(killSwitchMode: .advanced, excludeLocalNetworks: false) },
                        connectionProtocol: { .smartProtocol }
                    )
                    $0.tunnelManager = MockTunnelManager(connection: session)
                    $0.continuousClock = ImmediateClock()
                    $0.date = .constant(.now)
                }

                await store.send(.tunnel(.tunnelStatusChanged(.disconnected(.tunnelAborted)))) {
                    $0.tunnel = .disconnected(.tunnelAborted)
                    $0.$connectionState.withLock { $0 = .disconnected }
                }
                await store.receive(\.tunnel.startZeroPeerColdStart)
                await store.receive(\.connectionStateUpdated)
                await store.receive(\.delegate.stateChanged)
                await store.receive(\.reloadWidgetTimelines)
                await store.receive(\.tunnel.tunnelStartRequestFinished)
            }
        }
    #endif

    // TODO: ProTUN: Revisit and update tests that are still relevant
//    final class ConnectionFeatureTests: XCTestCase {
//        override func setUp() async throws {
//            try await super.setUp()
//
//            // Populate the user tier storage, since the intent resolver requires it for server selection
//            @Shared(.userTier) var userTier
//            $userTier.withLock { $0 = 2 }
//        }
//
//        /// Verifies that a connection can be queued up if the feature is in the disconnecting state and the user
//        /// attempts to connect somewhere, as well as both internal and external state changes as expected.
//        /// e.g. during reconnection, external state transitions to `.connecting`, skipping `.disconnected`.
//        @MainActor
//        func testStartingConnectionWhileDisconnecting() async {
//            let mockVPNSession = VPNSessionMock(status: .disconnecting, connectedDate: nil, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockVPNSession)
//            let mockClock = TestClock()
//
//            let now = Date.now
//            let tomorrow = now.addingTimeInterval(.days(1))
//            let intentResolutionExpectation = XCTestExpectation(description: "Preparation should be invoked")
//
//            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
//            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
//            let mockStorage = VpnAuthenticationStorage.testStorage(keys: keys, certificate: certificate)
//
//            let connectionFeatures: AgentTunnelFeatures = .mock
//            let server = Server.ca
//            let reconnectingServerID = server.endpoint.id
//            let initialIntent = ServerConnectionIntent.mock()
//            let reconnectionSpec = ConnectionSpec(location: .country(code: "CA", order: .fastest), features: [])
//            let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec)
//            let preparedReconnectionIntent = ServerConnectionIntent.mock(
//                withSpecLocation: .country(code: "CA", order: .fastest),
//                server: server,
//                protocolConfiguration: .wireGuard(.init(backend: .go, transport: .tls, features: .unimplementedFeatures)),
//                features: connectionFeatures
//            )
//
//            let coreState = CoreConnectionFeature.State(tunnelState: .disconnecting(nil))
//
//            let initialState = ConnectionFeature.State(
//                connectionState: .resolving,
//                shouldRegisterServerChangeOnConnection: false,
//                core: coreState
//            )
//
//            let store = TestStore(initialState: initialState) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.date = .constant(now)
//                $0.continuousClock = mockClock
//                $0.tunnelManager = mockManager
//                $0.vpnAuthenticationStorage = mockStorage
//                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
//                $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
//                $0.connectionIntentResolver.resolve = { _ in
//                    intentResolutionExpectation.fulfill()
//                    return preparedReconnectionIntent
//                }
//                $0.defaultAppStorage = .testValue()
//            }
//
//            await store.send(.input(.onLaunch))
//            await store.receive(\.core.startObserving)
//            await store.receive(\.core.tunnel.startObserving)
//            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnecting)
//
//            // Connection feature is in the 'disconnecting' state, now let's send a connection request
//            await store.send(.input(.connect(reconnectionPreparationIntent))) {
//                // TODO: ProTUN: Revisit
    ////                $0.reconnectionIntent = reconnectionPreparationIntent
//                $0.connectionState = .connecting(.unresolved(reconnectionPreparationIntent))
//            }
//            await store.receive(stateChange(to: \.connecting.unresolved))
//
//            mockVPNSession.status = .disconnected // Simulate the disconnection attempt finishing
//            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnected) {
//                $0.core.tunnel = .disconnected(nil)
//            }
//            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected)) { _ in
//                // TODO: ProTUN: Revisit
    ////                $0.reconnectionIntent = nil
//            }
//
//            // Now that we are fully disconnected, the queued connection attempts should immediately start
//            await store.receive(\.prepare)
//            await store.receive(\.finishedPreparing.success) {
//                $0.connectionState = .connecting(.resolved(preparedReconnectionIntent, server))
//            }
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await fulfillment(of: [intentResolutionExpectation], timeout: 0) // Let's verify port selection occurred before connection
//            await store.receive(\.core.connect)
//            await store.receive(\.core.tunnel.connect)
//            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting) {
//                $0.core.tunnel = .connecting
//            }
//            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
//            await store.receive(\.core.tunnel.tunnelStartRequestFinished.success)
//
//            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
//            await store.receive(\.core.tunnel.tunnelStatusChanged.connected) {
//                $0.core.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: reconnectingServerID, connectionDate: now, protocolData: .wireGuardGo))
//            }
//            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
//
//            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
//            await store.receive(coreStateChange(from: \.connecting, to: \.connected)) {
//                $0.connectionState = .connected(preparedReconnectionIntent, server, now, nil)
//            }
//            await store.receive(stateChange(to: \.connected))
//
//            await store.send(.stopObserving)
//            await store.receive(\.core.stopObserving)
//            await store.receive(\.core.tunnel.stopObserving)
//        }
//
//        /// Verifies that a connection can be queued up if the feature is in the connected state already, as well as
//        /// both internal and external state changes as expected.
//        /// e.g. during reconnection, external state transitions to `.connecting`, skipping `.disconnected`.
//        @MainActor
//        func testStartingConnectionWhileConnectedResultsInReconnection() async {
//            @Shared(.userTier) var userTier = 2
//            let now = Date.now
//            let tomorrow = now.addingTimeInterval(.days(1))
//            let intentResolutionExpectation = XCTestExpectation(description: "Port selector should be invoked")
//
//            let mockVPNSession = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockVPNSession)
//            let mockClock = TestClock()
//
//            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
//            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
//            let mockStorage = VpnAuthenticationStorage.testStorage(keys: keys, certificate: certificate)
//
//            let connectionFeatures: AgentTunnelFeatures = .mock
//            let initialServerID = Server.mock.endpoint.id
//            let initialIntent = ServerConnectionIntent.mock()
//
//            let serverToReconnectTo = Server.ca
//            let reconnectionSpec = ConnectionSpec(location: .country(code: "CA", order: .fastest), features: [])
//            let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec)
//            let preparedReconnectionIntent = ServerConnectionIntent.mock(
//                withSpecLocation: .country(code: "CA", order: .fastest),
//                server: serverToReconnectTo,
//                protocolConfiguration: .wireGuard(.init(backend: .go, transport: .tls, features: .unimplementedFeatures)),
//                features: connectionFeatures
//            )
//
//            // Because of the initial value we observe in `ExtensionFeature.Action.startObserving`, we can't fully
//            // accurately model starting a reducer in the fully connected state yet.
//            // It's not a problem, since we always start from the resolving state when running in the app.
//            let coreState = CoreConnectionFeature.State(tunnelState: .connecting)
//
//            let initialState = ConnectionFeature.State(
//                connectionState: .resolving,
//                shouldRegisterServerChangeOnConnection: false,
//                core: coreState
//            )
//
//            let store = TestStore(initialState: initialState) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.date = .constant(now)
//                $0.continuousClock = mockClock
//                $0.tunnelManager = mockManager
//                $0.vpnAuthenticationStorage = mockStorage
//                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
//                $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
//                $0.connectionIntentResolver.resolve = { _ in
//                    intentResolutionExpectation.fulfill()
//                    return preparedReconnectionIntent
//                }
//                $0.defaultAppStorage = .testValue()
//            }
//
//            // Let's skip repeating assertions we've covered in previous tests
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await mockClock.advance(by: .seconds(2))
//            await store.receive(stateChange(to: \.connected))
//
//            // Connection feature is in the 'connected' state, now let's send a connection request
//            await store.send(.input(.connect(reconnectionPreparationIntent))) { _ in
//                // TODO: ProTUN: Revisit
    ////                $0.reconnectionIntent = reconnectionPreparationIntent
//            }
//            await store.receive(\.core.disconnect)
//            await mockClock.advance(by: .seconds(1))
//            await store.receive(coreStateChange(from: \.connected, to: \.disconnecting))
//            await store.receive(stateChange(to: \.connecting))
//            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected))
//
//            // We've finally disconnected, so it's now sensible to start port/protocol selection
//            // Now that we are fully disconnected, the queued connection attempts should immediately start
//            await store.receive(\.prepare)
//            await store.receive(\.finishedPreparing) { _ in
//                // TODO: ProTUN: Revisit
    ////                $0.currentIntent = .active(preparedReconnectionIntent)
//            }
//
//            await fulfillment(of: [intentResolutionExpectation], timeout: 0)
//            await store.receive(\.core.connect)
//            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
//            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
//            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
//            await mockClock.advance(by: .seconds(1)) // Give LocalAgent time to connect
//            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
//            await store.receive(stateChange(to: \.connected))
//        }
//
//        @MainActor
//        func testDisconnectDuringPreparationCancelsConnection() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//
//            store.dependencies.connectionIntentResolver = .init(resolve: { _ throws(IntentResolutionError) in
//                @Dependency(\.continuousClock) var clock
//                do {
//                    try await clock.sleep(for: .seconds(2))
//                    try Task.checkCancellation()
//                } catch {
//                    throw .cancelled
//                }
//                XCTFail("Preparation should have been cancelled")
//                return .mock()
//            }, authorize: { _, _ in
//            })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(preparationIntent)))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved)) {
//                $0.connectionState = .connecting(.unresolved(preparationIntent))
//            }
//
//            await environment.clock.advance(by: .seconds(1))
//
//            await store.send(.input(.disconnect))
//
//            await environment.clock.advance(by: .seconds(1))
//
//            await store.receive(stateChange(to: \.disconnected)) {
//                $0.connectionState = .disconnected
//            }
//        }
//
//        @MainActor
//        func testUserDisconnectClearsQueuedReconnectionIntent() async {
//            let queuedIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//            let activeIntent = ServerConnectionIntent.mock()
//            let now = Date.now
//            let clock = TestClock()
//            let mockSession = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockSession)
//
//            let state = ConnectionFeature.State(
//                connectionState: .connecting(.unresolved(queuedIntent)),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .connected(
//                        .ike,
//                        ConnectionData(serverID: activeIntent.server.endpoint.id, connectionDate: now, protocolData: .ike)
//                    )
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.continuousClock = clock
//                $0.tunnelManager = mockManager
//            }
//            store.exhaustivity = .off
//
//            await store.send(.input(.disconnect)) { _ in
//                // TODO: ProTUN: Revisit
    ////                $0.reconnectionIntent = nil
//            }
//        }
//
//        @MainActor
//        func testUserDisconnectSendsCoreDisconnectWhenCoreAppearsDisconnected() async {
//            let activeIntent = ServerConnectionIntent.mock()
//            let now = Date.now
//            let mockSession = VPNSessionMock(status: .disconnected, connectedDate: now, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockSession)
//
//            let state = ConnectionFeature.State(
//                connectionState: .connecting(.resolved(activeIntent, activeIntent.server)),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .disconnected(nil)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.tunnelManager = mockManager
//            }
//            store.exhaustivity = .off
//
//            await store.send(.input(.disconnect)) {
//                $0.connectionState = .disconnected
//            }
//            await store.receive(\.core.disconnect.userIntent)
//        }
//
//        @MainActor
//        func testIgnoresConnectedTransitionWhileDisconnectingIntent() {
//            let now = Date.now
//            let disconnectingIntent = ServerConnectionIntent.mock()
//            let queuedReconnectionIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//            let connectedData = ConnectionData(
//                serverID: disconnectingIntent.server.endpoint.id,
//                connectionDate: now,
//                protocolData: .wireGuardGo
//            )
//            let certificate = VpnCertificate(
//                certificate: "1234",
//                validUntil: now.addingTimeInterval(.hours(1)),
//                refreshTime: now.addingTimeInterval(.hours(1))
//            )
//
//            let state = ConnectionFeature.State(
//                connectionState: .connecting(.unresolved(queuedReconnectionIntent)),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .connected(.wireGuard(.go), connectedData)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.tunnelManager = MockTunnelManager(connection: VPNSessionMock(status: .connected))
//                $0.continuousClock = TestClock()
//            }
//            store.exhaustivity = .off
//
//            // TODO: ProTUN: Revisit
    ////            await store.send(.core(.delegate(.stateChanged(
    ////                .connecting(connectedData),
    ////                .connected(connectedData, now, nil)
    ////            )))) {
    ////                $0.reconnectionIntent = queuedReconnectionIntent
    ////            }
//        }
//
//        @MainActor
//        func testDisconnectedTransitionClearsStaleCurrentIntentWhenNoQueuedReconnect() async {
//            let activeIntent = ServerConnectionIntent.mock()
//            let state = ConnectionFeature.State(
//                connectionState: .disconnecting(activeIntent, activeIntent.server),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .disconnecting(nil)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            }
//            store.exhaustivity = .off
//
//            // TODO: ProTUN: Revisit
    ////            await store.send(.core(.delegate(.stateChanged(
    ////                .disconnecting,
    ////                .disconnected(nil)
    ////            )))) {
    ////                $0.connectionState = .disconnected
    ////            }
//            await store.receive(\.delegate.stateChanged.disconnected)
//        }
//
//        /// When the OS reports the tunnel as `.connected` but the stored connection intent
//        /// disagrees with the actual tunnel protocol (e.g. previous in-app session was
//        /// WireGuard but the user started IKEv2 from System Settings), the feature must
//        /// synthesise a fresh intent from `ConnectionData` so the UI doesn't render stale
//        /// protocol/server information.
//        @MainActor
//        func testConnectedWithMismatchedStoredProtocolSynthesizesIntent() {
//            let now = Date.now
//            let staleStoredIntent = ServerConnectionIntent.mock(
//                protocolConfiguration: .wireGuard(.init(
//                    backend: .go,
//                    transport: .udp,
//                    features: .unimplementedFeatures
//                ))
//            )
//            let actualServer = Server.ca
//            let connectedData = ConnectionData(
//                serverID: actualServer.endpoint.id,
//                connectionDate: now,
//                protocolData: .ike
//            )
//
//            let state = ConnectionFeature.State(
//                connectionState: .resolving,
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .connected(.ike, connectedData)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.serverIdentifier = .init(fullServerInfo: { _ in actualServer })
//                $0.connectionFeatureProvider.connectionFeatures = { .unimplementedFeatures }
//                $0.connectionFeatureProvider.requestedFeatures = { .unimplementedFeatures }
//            }
//            store.exhaustivity = .off
//
//            // TODO: ProTUN: Revisit everything below
    ////            await store.send(.core(.delegate(.stateChanged(
    ////                .connecting(connectedData),
    ////                .connected(connectedData, now, nil)
    ////            ))))
//
//            // currentIntent should reflect the real tunnel: IKE on actualServer, not the
//            // stale WireGuard storedIntent.
    ////            guard case let .active(resolved) = store.state.currentIntent else {
    ////                XCTFail("Expected currentIntent to be .active after .connected")
    ////                return
    ////            }
    ////            XCTAssertEqual(resolved.protocolConfiguration, .ike)
    ////            XCTAssertEqual(resolved.server.endpoint.id, actualServer.endpoint.id)
    ////            guard case let .connected(intent, server, _, _) = store.state.connectionState else {
    ////                XCTFail("Expected connectionState to be .connected after .connected delegate")
    ////                return
    ////            }
    ////            XCTAssertEqual(intent.protocolConfiguration, .ike)
    ////            XCTAssertEqual(server.endpoint.id, actualServer.endpoint.id)
//        }
//
//        @MainActor
//        func testDisconnectingTransitionWithQueuedReconnectDoesNotRequireStoredIntent() async {
//            let now = Date.now
//            let activeIntent = ServerConnectionIntent.mock()
//            let queuedReconnectionIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//            let connectedData = ConnectionData(
//                serverID: activeIntent.server.endpoint.id,
//                connectionDate: now,
//                protocolData: .ike
//            )
//
//            let state = ConnectionFeature.State(
//                connectionState: .connected(activeIntent, activeIntent.server, now, nil),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .connected(.ike, connectedData)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: { _ in
//            }
//            store.exhaustivity = .off
//
//            // TODO: ProTUN: Revisit
    ////            await store.send(.core(.delegate(.stateChanged(
    ////                .connected(connectedData, now, nil),
    ////                .disconnecting
    ////            )))) {
    ////                $0.connectionState = .connecting(.unresolved(queuedReconnectionIntent))
    ////            }
//            await store.receive(\.delegate.stateChanged.connecting.unresolved)
//        }
//
//        @MainActor
//        func testQueuedReconnectAfterStartupConnectedForcesDisconnectOfExistingTunnel() async {
//            let now = Date.now
//            let connectedIntent = ServerConnectionIntent.mock()
//            let queuedReconnectionIntent = ConnectionPreparationIntent(
//                spec: ConnectionSpec(location: .country(code: "CH", order: .fastest), features: [])
//            )
//            let connectedData = ConnectionData(
//                serverID: connectedIntent.server.endpoint.id,
//                connectionDate: now,
//                protocolData: .ike
//            )
//
//            let state = ConnectionFeature.State(
//                connectionState: .connecting(.unresolved(queuedReconnectionIntent)),
//                shouldRegisterServerChangeOnConnection: false,
//                core: .init(
//                    tunnelState: .connected(.ike, connectedData)
//                )
//            )
//
//            let store = TestStore(initialState: state) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.continuousClock = TestClock()
//                $0.tunnelManager = MockTunnelManager(connection: VPNSessionMock(status: .connected))
//            }
//            store.exhaustivity = .off
//
//            // TODO: ProTUN: Revisit
    ////            await store.send(.core(.delegate(.stateChanged(
    ////                .unknown,
    ////                .connected(connectedData, now, nil)
    ////            ))))
//            await store.receive(\.core.disconnect.userIntent)
//        }
//
//        /// Connection preparation must be completed while disconnected from the VPN.
//        /// Upon finishing preparation, if we find that the core connection state is not disconnected, the tunnel has
//        /// likely been started externally, and we cannot guarantee that the feature is ready to handle the connection
//        /// attempt, so it should be disconnected with an error.
//        @MainActor
//        func testExternalConnectionDuringPreparationHandledByDisconnectingWithError() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.dependencies.smartPortSelector = .init(select: { _, _ in
//                @Dependency(\.continuousClock) var clock
//                try? await clock.sleep(for: .seconds(2))
//                return .init(chosenProtocol: .wireGuard(.udp), ports: [1337])
//            })
//
//            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(preparationIntent)))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved)) {
//                $0.connectionState = .connecting(.unresolved(preparationIntent))
//            }
//
//            // Give some time for preparation to start
//            await environment.clock.advance(by: .seconds(1))
//
//            // Halfway during preparation, the tunnel is started either by the system due to on-demand rules, or by the
//            // user from the control centre (they must be fast because preparation is only ~1s long!)
//            environment.vpnSession.status = .connecting
//            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting)
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            // Advance the clock so that preparation finishes
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(\.finishedPreparing.success)
//            await store.receive(\.core.disconnect.connectionFailure.preparation.featureNotReady)
//            await store.receive(\.delegate.connectionFailed.preparation.featureNotReady)
//            await store.receive(stateChange(to: \.disconnecting))
//
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected)) {
//                $0.connectionState = .disconnected
//            }
//        }
//
//        @MainActor
//        func testFeatureDelaysInternalDisconnectWhenStartingTunnelUntilTunnelStartSucceeds() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//            store.exhaustivity = .off
//
//            // Let's manually model what tunnel state transitions.
//            environment.vpnSession.startupDuration = nil
//            environment.vpnSession.connectionDuration = nil
//            environment.vpnSession.disconnectionDuration = nil
//
//            // Let's make sure tunnel stop is not called too early
//            environment.tunnelManager.didStopTunnelCallback = { XCTFail("Tunnel was stopped too early") }
//
//            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            // Connection
//            await store.send(.input(.connect(preparationIntent)))
//
//            await store.receive(\.core.tunnel.connect)
//            environment.vpnSession.status = .connecting // Sends a `NEVPNStatusDidChange` notification
//            await store.receive(\.core.tunnel.tunnelStatusChanged.connecting) {
//                $0.core.tunnel = .connecting
//            }
//
//            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
//
//            // The extension has started, but must not be interrupted until it is connected.
//            // If the user cancels the connection, we *must not* send a `tunnel.disconnect` action until the tunnel is
//            // either in the `connected` or `disconnected` state
//
//            await store.send(.input(.disconnect))
//            await store.receive(stateChange(to: \.disconnecting))
//
//            let tunnelStopInvoked = XCTestExpectation(description: "Tunnel stop should have been requested")
//            environment.tunnelManager.didStopTunnelCallback = { tunnelStopInvoked.fulfill() }
//
//            environment.vpnSession.connectedDate = .now
//            environment.vpnSession.status = .connected
//
//            await store.receive(\.core.tunnel.tunnelStatusChanged.connected)
//            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
//
//            // Finally, the tunnel is ready to be stopped, and we should proceed with the disconnection
//            await store.receive(\.core.disconnect)
//            await store.receive(\.core.tunnel.disconnect)
//            environment.vpnSession.status = .disconnecting
//            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnecting)
//            await store.receive(coreStateChange(from: \.connecting, to: \.disconnecting))
//
//            await fulfillment(of: [tunnelStopInvoked], timeout: 0)
//
//            environment.vpnSession.status = .disconnected
//            await store.receive(\.core.tunnel.tunnelStatusChanged.disconnected)
//            await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected))
//            await store.receive(stateChange(to: \.disconnected))
//            await store.send(.stopObserving)
//        }
//
//        @MainActor
//        func testConnectionStateResolvesToDisconnected() async {
//            let mockVPNSession = VPNSessionMock(status: .disconnected, connectedDate: nil, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockVPNSession)
//
//            let store = TestStore(initialState: .initialState) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.tunnelManager = mockManager
//            }
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(coreStateChange(from: \.unknown, to: \.disconnected))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testConnectionStateResolvesToConnected() async {
//            let now = Date.now
//            let tomorrow = now.addingTimeInterval(.days(1))
//            let mockClock = TestClock()
//            let mockVPNSession = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
//            let mockManager = MockTunnelManager(connection: mockVPNSession)
//
//            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
//            let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
//            let mockStorage = VpnAuthenticationStorage.testStorage(
//                keys: keys,
//                certificate: certificate,
//                features: .mock
//            )
//
//            let store = TestStore(initialState: .initialState) {
//                ConnectionFeature()
//            } withDependencies: {
//                $0.date = .constant(now)
//                $0.continuousClock = mockClock
//                $0.tunnelManager = mockManager
//                $0.connectionFeatureProvider.connectionFeatures = { .mock }
//                $0.vpnAuthenticationStorage = mockStorage
//                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
//            }
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await mockClock.advance(by: .seconds(2))
//            await store.receive(coreStateChange(from: \.unknown, to: \.connecting))
//            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
//            await store.receive(stateChange(to: \.connected))
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenPreparationFails() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            // Set up a failure that should happen during connection preparation
//            let preparationError = IntentResolutionError.unexpectedProtocol(.ike)
//            store.dependencies.connectionIntentResolver = .init(resolve: { _ throws(IntentResolutionError) in
//                @Dependency(\.continuousClock) var clock
//                do {
//                    try await clock.sleep(for: .seconds(1))
//                } catch {
//                    throw .cancelled
//                }
//                throw preparationError
//            }, authorize: { _, _ in
//            })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved))
//
//            await environment.clock.advance(by: .seconds(1))
//
//            await store.receive(\.finishedPreparing.failure)
//            await store.receive(stateChange(to: \.disconnected))
//            await store.receive(\.delegate.connectionFailed.preparation)
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenPortSelectionFails() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            // Let's make sure that if the server does not respond to our pings on any port, we error out immediately
//            let protocolSelectionResult = ServerEndpointPortResolution(chosenProtocol: .wireGuard(.udp), ports: [])
//            store.dependencies.smartPortSelector = .init(select: { _, _ in protocolSelectionResult })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved))
//
//            await environment.clock.advance(by: .seconds(1))
//
//            await store.receive(\.finishedPreparing.failure)
//            await store.receive(stateChange(to: \.disconnected))
//            // await store.receive(\.delegate.connectionFailed.preparation.intentResolution.portSelectionFailed)
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenAuthorizerThrows() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            // Set up a failure that should happen during connection preparation
//            store.dependencies.connectionIntentResolver = .init(resolve: { _ in
//                XCTFail("Shouldn't get to preparation step, authorization should fail first")
//                return .mock()
//            }, authorize: { _, _ throws(ConnectionIntentResolutionError) in
//                throw ConnectionIntentResolutionError.specificCountryUnavailable(countryCode: "US")
//            })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive { action in
//                guard case let .delegate(.intentResolutionFailed(_, error)) = action,
//                      case let .specificCountryUnavailable(countryCode) = error,
//                      countryCode == "US" else {
//                    return false
//                }
//                return true
//            }
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenTunnelStartFails() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            // Set up a failure to occur while starting the tunnel
//            let tunnelStartError = NSError(domain: NEVPNErrorDomain, code: 4)
//            environment.tunnelManager.tunnelStartErrorToThrow = tunnelStartError
//
//            let preparationIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(preparationIntent)))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved)) { $0.connectionState = .connecting(.unresolved(preparationIntent)) }
//            await store.receive(\.finishedPreparing.success)
//            await store.receive(stateChange(to: \.connecting.resolved))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//            await store.receive(\.delegate.connectionFailed.tunnel.tunnelStartFailed)
//
//            await store.send(.stopObserving)
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenCertAuthFails() async {
//            let environment = ConnectionEnvironment.disconnected(certificateState: .expired)
//            let store = environment.createConnectionTestStore()
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnecting))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenLocalAgentConnectionCreationFails() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnecting))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenConnectionTimesOut() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await environment.clock.advance(by: .seconds(29))
//            await store.receive(\.delegate.connectionFailed.timeout)
//            await store.receive(stateChange(to: \.disconnecting))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testFeatureSendsDelegateActionWhenSessionForkingFails() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.dependencies.vpnAuthenticationStorage.getStoredCertificate = { nil }
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await environment.clock.advance(by: .seconds(29))
//            await store.receive(stateChange(to: \.disconnecting))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testFeatureCancelsFirstPreparationWhenSecondConnectionRequested() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            let canadaSpec = ConnectionSpec(location: .country(code: "CA", order: .fastest), features: [])
//            let firstIntent = ConnectionPreparationIntent(spec: .defaultFastest)
//            let secondIntent = ConnectionPreparationIntent(spec: canadaSpec)
//
//            let expectedResolvedIntent = ServerConnectionIntent(spec: canadaSpec, server: .ca, protocolConfiguration: .wireGuard(.mock), features: .mock)
//
//            store.dependencies.connectionIntentResolver = .init(resolve: { intent throws(IntentResolutionError) in
//                @Dependency(\.continuousClock) var clock
//                do {
//                    try await clock.sleep(for: .seconds(2))
//                } catch {
//                    throw .cancelled
//                }
//                return .init(spec: intent.spec, server: .ca, protocolConfiguration: .wireGuard(.mock), features: .mock)
//            }, authorize: { _, _ in
//            })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(firstIntent)))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved)) {
//                $0.connectionState = .connecting(.unresolved(firstIntent))
//            }
//
//            await environment.clock.advance(by: .seconds(1)) // preparation effect should be in-flight
//
//            await store.send(.input(.connect(secondIntent)))
//            await store.receive(stateChange(to: \.connecting.unresolved)) {
//                $0.connectionState = .connecting(.unresolved(secondIntent))
//            }
//
//            await environment.clock.advance(by: .seconds(2)) // second effect should finish
//            await store.receive(\.finishedPreparing.success)
//            await store.receive(stateChange(to: \.connecting.resolved)) {
//                // Assert that the second effect finished, not the first
//                $0.connectionState = .connecting(.resolved(expectedResolvedIntent, .ca))
//            }
//        }
//
//        /// Tests that after failing to connect, the next successful connection attempt transitions through all expected states.
//        @MainActor
//        func testFeatureStateTransitionsOnSecondConnectionAfterFirstFailedConnection() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            // Set up a failure that should happen during tunnel start
//            let entryUnavailableError = WireguardConfiguratorError.entryUnavailableForTransport(.udp)
//            environment.tunnelManager.tunnelStartErrorToThrow = ConnectionError.tunnel(.tunnelStartFailed(entryUnavailableError))
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved))
//
//            await store.receive(\.finishedPreparing.success)
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await store.receive(stateChange(to: \.disconnected))
//            await store.receive(\.delegate.connectionFailed.tunnel.tunnelStartFailed)
//
//            // This time, connection should succeed
//            environment.tunnelManager.tunnelStartErrorToThrow = nil
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(\.prepare)
//            await store.receive(stateChange(to: \.connecting.unresolved))
//
//            await store.receive(\.finishedPreparing.success)
//            await store.receive(stateChange(to: \.connecting.resolved))
//
//            await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
//
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(coreStateChange(from: \.starting, to: \.connecting))
//
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(coreStateChange(from: \.connecting, to: \.connected))
//            await store.receive(stateChange(to: \.connected))
//        }
//
//        @MainActor
//        func testConnectionTimesOutIfNeverUnjailedByRestrictedServer() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.connecting.resolved))
//            await environment.clock.advance(by: .seconds(1))
//
//            // When connecting to a restricted server, we are hardjailed and must wait until it can verify our certificate
//            // has not been revoked
//            await environment.clock.advance(by: .seconds(28))
//
//            // The server failed to authenticate us in time, so we should time out
//            await store.receive(\.delegate.connectionFailed.timeout)
//            await store.receive(stateChange(to: \.disconnecting))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.disconnected))
//        }
//
//        @MainActor
//        func testConnectionSucceedsOnceUnjailedByRestrictedServer() async {
//            let environment = ConnectionEnvironment.disconnected()
//            let store = environment.createConnectionTestStore()
//
//            store.dependencies.serverSelector = .init(select: { _, _, _ in .ca })
//
//            store.exhaustivity = .off
//            await store.send(.input(.onLaunch))
//            await store.receive(stateChange(to: \.disconnected))
//
//            await store.send(.input(.connect(.init(spec: .defaultFastest))))
//            await store.receive(stateChange(to: \.connecting.unresolved))
//            await environment.clock.advance(by: .seconds(1))
//            await store.receive(stateChange(to: \.connecting.resolved))
//            await environment.clock.advance(by: .seconds(1))
//
//            await store.receive(stateChange(to: \.connected))
//
//            // Let's fast forward to when we would have timed out, had the server not unjailed us
//            await environment.clock.advance(by: .seconds(15))
//        }
//
//        // NOTE: develop's reachability/connectivity tests were removed during the ProTUN rebase.
//        // App-side reachability / `core.currentNwStatus` tracking is no longer part of ConnectionFeature —
//        // network-path monitoring is managed on the extension side (ProTUN is iOS-first here).
//        // Reintroduce macOS startup reachability handling on ProTUN's terms when that work resumes. (VPNAPPL-3047)
//
//        private func stateChange(
//            to expectedState: PartialCaseKeyPath<ConnectionState>,
//            strict: Bool = true
//        ) -> (ConnectionFeature.Action) -> Bool {
//            { action in
//                guard case let .delegate(.stateChanged(state)) = action else {
//                    return false
//                }
//                if state.is(expectedState) {
//                    return true
//                }
//                if strict {
//                    XCTFail("Received state change action, but to the incorrect state (\(caseName(of: state)))")
//                }
//                return false
//            }
//        }
//    }

    fileprivate func caseName(of value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        return String(describing: mirror.children.first?.label ?? "\(value)")
    }

    extension ConnectionPreparationIntent {
        init(spec: ConnectionSpec) {
            self.init(spec: spec, acceptableProtocols: .all)
        }
    }
#endif
