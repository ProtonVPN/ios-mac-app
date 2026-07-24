//
//  Created on 06/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

#if DEBUG // `MockTunnelManager` is only built for the simulator
    import ComposableArchitecture
    import Domain
    import DomainTestSupport
    import Ergonomics
    @testable import ExtensionManager
    import Foundation
    import os
    import Testing

    @Suite(.serialized)
    struct ExtensionManagerFeatureTests {
        @Test
        @MainActor
        func requestsTunnelStart() async {
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let server = Server.ca // Canadian server mock
            let features = AgentTunnelFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features, tunnelFeatures: .mock)
            let now = Date.now

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )
            // Drive the `.connecting` transition manually so the tunnel-start request and the observed status change
            // can't race. With the default `startupDuration` of zero, `startTunnel()` flips the status to `.connecting`
            // synchronously (yielding through the observation stream) before the same effect sends
            // `.tunnelStartRequestFinished`, leaving the delivery order of those two actions non-deterministic.
            mockManager.connection.startupDuration = nil

            let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                ExtensionFeature()
            } withDependencies: {
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.date = .constant(now)
            }

            await store.send(.startObserving)
            await store.receive(\.tunnelStatusChanged.disconnected)

            await store.send(.connect(intent))
            await store.receive(\.tunnelStartRequestFinished)

            // Now that the start request has completed, simulate the extension reporting the connecting state.
            mockManager.connection.status = .connecting
            await store.receive(\.tunnelStatusChanged.connecting) {
                $0 = .connecting(
                    TunnelConfiguration(
                        connectionSpec: .defaultFastest,
                        tunnelProtocol: .wireGuard,
                        peerIDs: ["peer-id"],
                        killSwitch: false
                    ),
                    tunnelActive: false
                )
            }

            await store.send(.stopObserving)
        }

        @Test
        @MainActor
        func stateSetToConnectedIfExistingTunnelIsConnected() async {
            let mockManager = MockTunnelManager()
            mockManager.connection = VPNSessionMock(
                status: .connected,
                connectedDate: nil,
                lastDisconnectError: nil
            )
            mockManager.connection.connectedServerID = "peer-id"
            let now = Date.now

            let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                ExtensionFeature()
            } withDependencies: {
                $0.tunnelManager = mockManager
                $0.date = .constant(now)
            }

            await store.send(.startObserving)
            await store.receive(\.tunnelStatusChanged.connected) {
                $0 = .connected(
                    TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"], killSwitch: false),
                    DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
                )
            }

            await store.send(.stopObserving)
        }

        /// A server change while connected over IKEv2 must start a fresh tunnel: there is no extension to message, so
        /// the in-place update route is unavailable. The exhaustive store fails this test if the reducer emits
        /// `requestConfigChange` instead, and the message handler fails it if anything reaches the provider rail.
        @Test
        @MainActor
        func serverChangeWhileConnectedOverIKEStartsFreshTunnel() async {
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()
            let now = Date.now

            mockManager.connection = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
            mockManager.connection.messageHandler = { _, request in
                Issue.record("No provider message expected when changing servers from IKEv2, got: \(request.payload)")
                return .init(payload: .ack)
            }

            let intent = ServerConnectionIntent(
                spec: .defaultFastest,
                server: .ca,
                protocolConfiguration: .wireGuard(TunnelSettings.mock),
                features: .mock,
                tunnelFeatures: .mock
            )
            let connectedOverIKE = TunnelState.connected(
                TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["server-id"], killSwitch: false),
                DynamicConnectionData(currentPeerId: "server-id", connectionDate: now, protocolConnectionData: .ike)
            )

            let store = TestStore(initialState: connectedOverIKE) {
                ExtensionFeature()
            } withDependencies: {
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.date = .constant(now)
            }

            await store.send(.connect(intent))
            await store.receive(\.tunnelStartRequestFinished.success)

            await store.send(.stopObserving)
        }

        /// The counterpart: over WireGuard the same server change stays on the in-place route, and the derived
        /// update reaches the extension as a provider message.
        @Test
        @MainActor
        func serverChangeWhileConnectedOverWireGuardUpdatesInPlace() async {
            let mockManager = MockTunnelManager()
            let now = Date.now
            let sentUpdate = OSAllocatedUnfairLock<ConnectionUpdate?>(initialState: nil)

            mockManager.connection = VPNSessionMock(status: .connected, connectedDate: now, lastDisconnectError: nil)
            mockManager.connection.messageHandler = { _, request in
                guard case let .updateConfiguration(update) = request.payload else {
                    Issue.record("Expected a configuration update, got: \(request.payload)")
                    return .init(payload: .ack)
                }
                sentUpdate.withLock { $0 = update }
                return .init(payload: .ack)
            }

            let intent = ServerConnectionIntent(
                spec: .defaultFastest,
                server: .ca,
                protocolConfiguration: .wireGuard(TunnelSettings.mock),
                features: .mock,
                tunnelFeatures: .mock
            )
            let connectedOverWireGuard = TunnelState.connected(
                TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["server-id"], killSwitch: false),
                DynamicConnectionData(currentPeerId: "server-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
            )

            let store = TestStore(initialState: connectedOverWireGuard) {
                ExtensionFeature()
            } withDependencies: {
                $0.tunnelManager = mockManager
                $0.tunnelProviderConfigurator = .init(
                    changes: { intent in ConnectionUpdate(location: .init(spec: intent.spec, peers: [])) },
                    configure: { _, _ in }
                )
            }

            await store.send(.connect(intent))
            await store.receive(\.requestConfigChange)

            #expect(sentUpdate.withLock { $0 }?.location?.spec == intent.spec)
        }

        @Test
        @MainActor
        func disconnectsWhenVPNConfigurationPermissionDenied() async {
            let mockClock = TestClock()
            let mockManager = MockTunnelManager()
            mockManager.connection = VPNSessionMock(
                status: .invalid,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                ExtensionFeature()
            } withDependencies: {
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
            }

            let server = Server.mock
            let features = AgentTunnelFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features, tunnelFeatures: .mock)

            await store.send(.startObserving)
            await store.receive(\.tunnelStatusChanged.invalid) {
                $0 = .invalid
            }

            let permissionDenied: Error = "NEVPNErrorDomain Code=5 permission denied" as GenericError
            mockManager.tunnelStartErrorToThrow = permissionDenied

            await store.send(.connect(intent))
            await store.receive(\.tunnelStartRequestFinished.failure)
            await store.receive(\.tunnelStatusChanged.disconnected) {
                $0 = .disconnected(.tunnelStartFailed(permissionDenied))
            }

            await store.send(.stopObserving)
        }

        #if os(macOS)
            /// The tunnel-data client follows the extension's announcements for exactly as long as the feature observes
            /// the tunnel, so `ExtensionState` can flow whether the extension is already running (the app launching
            /// into an existing tunnel) or starts later.
            @Test
            @MainActor
            func observationFollowsTunnelDataAnnouncements() async {
                let mockClock = TestClock()
                let mockManager = MockTunnelManager()
                mockManager.connection = VPNSessionMock(
                    status: .disconnected,
                    connectedDate: nil,
                    lastDisconnectError: nil
                )
                let following = OSAllocatedUnfairLock(initialState: false)

                let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                    ExtensionFeature()
                } withDependencies: {
                    $0.continuousClock = mockClock
                    $0.tunnelManager = mockManager
                    $0.tunnelDataXPC = TunnelDataXPC(
                        resume: { following.withLock { $0 = true } },
                        cancel: { following.withLock { $0 = false } }
                    )
                }

                await store.send(.startObserving)
                await store.receive(\.tunnelStatusChanged)
                let followingWhileObserving = following.withLock { $0 }
                #expect(followingWhileObserving)

                await store.send(.stopObserving).finish()
                let followingAfterStopping = following.withLock { $0 }
                #expect(followingAfterStopping == false)
            }
        #endif
    }
#endif
