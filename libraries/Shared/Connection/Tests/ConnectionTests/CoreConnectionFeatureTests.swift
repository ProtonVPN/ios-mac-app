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

#if DEBUG
    import Clocks
    import ComposableArchitecture
    @testable import Connection
    import ConnectionTestSupport
    @testable import CoreConnection
    import CoreConnectionTestSupport
    import Domain
    import DomainTestSupport
    import Ergonomics
    import ExtensionIPC
    @testable import ExtensionManager
    import Foundation
    import Network
    import Testing
    import VPNShared
    import VPNSharedTesting

    @Suite(.serialized)
    struct CoreConnectionFeatureTests {
        /// Happy path test. Uses mocked dependencies to verify that the `ExtensionManagerFeature` and `LocalAgentFeature`
        /// reducers are correctly coordinated by the `ConnectionFeature` reducer.
        @Test
        @MainActor
        func endToEndConnection() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()
            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give VPNSessionMock time to establish connection

            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await mockClock.advance(by: .seconds(1))

            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Disconnection

            await performDisconnection(store: store, clock: mockClock)

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// This test ensures that if the network extension is stopped while the certificate refresh process is active, we
        /// cancel any in-flight certificate refresh effects that would otherwise retry sending IPC messages to the
        /// extension after the tunnel is stopped, resulting in extra UNEX or TNAB errors after disconnecting.
        @Test
        @MainActor
        func cancelsCertificateRefreshEffectsWhenConnectionIsAborted() async {
            let now = Date.now
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockStorage = VpnAuthenticationStorage.testStorage(keys: .constantKeys)

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { .mock }

                // Let's control the lower level tunnel message sender instead
                $0.tunnelMessageSender.send = { message throws(ProviderMessageError) in
                    #expect(message == .refreshCertificate(features: .mock), "Expected cert refresh client to ask for refresh")

                    // Let's model a scenario where the cert refresh takes a long time because of poor network conditions.
                    // If the tunnel is stopped before it can respond to our message, the completion handler app-side will
                    // still be invoked, so it's important to verify that the task is cancelled so we don't retry sending
                    // messages.
                    @Dependency(\.continuousClock) var clock
                    do {
                        try await clock.sleep(for: .seconds(45))
                    } catch {
                        throw .cancelled
                    }

                    // After 45 seconds, the connection attempt should have been aborted, and therefore this task should have been cancelled.
                    if Task.isCancelled {
                        throw .cancelled
                    } else {
                        Issue.record("Expected task to have been cancelled")
                        return .ok(data: nil)
                    }
                }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: .mock)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)

            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            // Let's assume the connection attempt times out while the certificate refresh is still in progress
            // In this case, we don't receive a response to our certificate refresh IPC message until the tunnel is killed.
            await mockClock.advance(by: .seconds(30))
            await store.receive(\.timeout)
            await store.receive(\.disconnect.connectionFailure.timeout.refreshingCertificate) // Should cancel the cert-refresh effect
            await store.receive(\.delegate.error.timeout.refreshingCertificate)
            await store.receive(\.tunnel.disconnect)
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }
            await store.receive(stateChange(from: \.connecting, to: \.disconnecting))

            await mockClock.advance(by: .seconds(1))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

            // Advance the clock 30 more seconds just in case an erroneous retry happens
            await mockClock.advance(by: .seconds(30))
            // If we haven't received any additional cert-auth failures by now, then the test was successful.

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// In case the tunnel disconnects for some unexpected reason while we are in the process of loading or refreshing
        /// our certificate, make sure that the connection process is aborted and an error is raised instead of entering
        /// an infinite loop. Possible reasons for the tunnel disconnecting include user actions (turning off VPN via
        /// system UI) or packet tunnel provider process crashes.
        @Test
        @MainActor
        func disconnectsWithErrorWhenCertificateAuthenticationFinishesButTunnelIsNotConnected() async {
            let now = Date()
            let yesterday = now.addingTimeInterval(.days(-1))
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let oldCertificate = VpnCertificate(certificate: "1234", validUntil: yesterday, refreshTime: yesterday)
            let newCertificate = VpnCertificate(certificate: "5678", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures(
                netshield: .off,
                vpnAccelerator: false,
                bouncing: nil,
                natType: .moderateNAT,
                safeMode: false,
                portForwarding: false
            )
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: oldCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id
            var certRefreshStarted = false

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            // Give some time for the cert refresh process to start
            await mockClock.advance(by: .seconds(1))
            #expect(certRefreshStarted)

            // Simulate the tunnel crashing or being manually disconnected by the user
            mockManager.connection.status = .disconnected
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.connecting, to: \.disconnected))

            // Give some more time for the cert refresh process to finish
            await mockClock.advance(by: .seconds(1))

            // Now, because the network extension was unexpectly stopped, we should abort the connection process with an error
            await store.receive(\.disconnect.connectionFailure.tunnel.tunnelAborted)
            await store.receive(\.delegate.error.tunnel.tunnelAborted)
            await store.receive(\.tunnel.disconnect)

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)

            // Possible TCA bug: We receive the `certAuth.cancelRefreshes` effect, so certificate refresh
            // effects should have been cancelled. But they are not, and need to be explicitly skipped here.
            await store.skipInFlightEffects()
        }

        /// In case the tunnel disconnects for some unexpected reason after we have successfully connected, make sure that
        /// Local Agent is disconnected as well.
        /// Possible reasons for the tunnel disconnecting include user actions outside of the app (control centre or
        /// system VPN settings) or packet tunnel provider process crashes.
        @Test
        @MainActor
        func disconnectsLocalAgentIfTunnelIsStoppedExternally() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features: VPNConnectionFeatures = .mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: certificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected(nil))

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { features }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: .mock)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Simulate the tunnel crashing or being manually disconnected by the user
            mockManager.connection.status = .disconnected
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.connected, to: \.disconnected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// Tests how we handle an edge case where the API refuses to refresh our certificate due to key conflict.
        /// We have to purge our locally stored keys and interrupt the connetion process (since the tunnel will need to
        /// be reconnected with a new private key).
        @Test
        @MainActor
        func disconnectsWithErrorWhenCertificateAuthenticationFailsDueToKeyConflict() async {
            let now = Date()
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()
            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: nil
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await store.receive(\.tunnel.disconnect)
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }
            await store.receive(stateChange(from: \.connecting, to: \.disconnecting))

            await mockClock.advance(by: .seconds(1))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        @Test
        @MainActor
        func regeneratesKeysAndDisconnectsWhenLocalAgentFailsWithGoTLSError() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            var mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: certificate,
                features: .mock
            )
            mockStorage.deleteKeys = { Issue.record("Keys shouldn't be cleared until we encounter the Go TLS error") }

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)

            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            var keysCleared = false
            store.dependencies.vpnAuthenticationStorage.deleteKeys = { keysCleared = true }

            await mockClock.advance(by: .seconds(1))
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await store.receive(\.tunnel.disconnect)
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }

            #expect(keysCleared) // Make sure keys were also cleared from the keychain

            await mockClock.advance(by: .seconds(1))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)

            // Possible TCA bug: We receive the `certAuth.cancelRefreshes` effect, so certificate refresh
            // effects should have been cancelled. But they are not, and need to be explicitly skipped here.
            await store.skipInFlightEffects()
        }

        @Test
        @MainActor
        func disconnectsWithErrorWhenUnrecoverableLocalAgentErrorReceived() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Encounter an unrecoverable error

            await store.receive(\.tunnel.disconnect)
            await store.receive(stateChange(from: \.connected, to: \.disconnecting))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }

            await mockClock.advance(by: .milliseconds(250))
            await mockClock.advance(by: .milliseconds(750))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)

            // Ensure that the final state post-disconnection contains the error so that it can be shown in the UI
            let disconnectedWithPolicyViolationDelinquent: CoreConnectionFeature.State = .init(tunnelState: .disconnected)
            #expect(store.state == disconnectedWithPolicyViolationDelinquent)
        }

        @Test
        @MainActor
        func refreshesCertificateWhenLocalAgentReceivesCertificateExpiredErrorEvent() async {
            let now = Date.now
            let laterToday = now.addingTimeInterval(.hours(12))
            let tomorrow = now.addingTimeInterval(.days(1))
            let dayAfterTomorrow = tomorrow.addingTimeInterval(.days(1))

            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: dayAfterTomorrow, refreshTime: dayAfterTomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { features }
            }
            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Certificate expiration

            // Let's first make sure that we don't disconnect from LA and refresh our certificate if it's still valid
            store.dependencies.date = .constant(laterToday) // certificate doesn't expire until tomorrow
            await store.receive(stateChange(from: \.disconnecting, to: \.connecting))

            await mockClock.advance(by: .milliseconds(500))

            await store.receive(stateChange(from: \.connecting, to: \.connected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)

            let connectedWithRefreshedCertificate: CoreConnectionFeature.State = .init(
                tunnelState: .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            )
            #expect(store.state == connectedWithRefreshedCertificate)

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        @Test
        @MainActor
        func reconnectsLocalAgentWithCachedAuthWhenLocalAgentReportsConnectionErrorState() async {
            let now = Date.now
            let tomorrow = now.addingTimeInterval(.days(1))

            let mockManager = MockTunnelManager(connection: .init(status: .connected, connectedDate: now))
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            let connectedData = ConnectionData(
                serverID: Server.mock.endpoint.id,
                connectionDate: now,
                protocolData: .wireGuardGo
            )

            let connected = CoreConnectionFeature.State(
                tunnelState: .connected(.wireGuard(.go), connectedData)
            )

            let store = TestStore(initialState: connected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { features }
            }
            store.exhaustivity = .off

            await mockClock.advance(by: .seconds(1))

            // TODO: ProTUN, Revisit
//            let hasRestartedLocalAgentConnection =
//                store.state.localAgent.is(\.connecting) || store.state.localAgent.is(\.connected)
//            #expect(hasRestartedLocalAgentConnection)
//            let loadedCertificate: VpnCertificate? = if case let .loaded(data) = store.state.certAuth {
//                data.certificate
//            } else {
//                nil
//            }
//            #expect(loadedCertificate == mockCertificate)

            // Cert auth loading schedules refresh effects. Drain them to avoid end-of-test flakiness.
            await store.skipInFlightEffects()
        }

        @Test
        @MainActor
        func disconnectsWithTimeoutErrorWhenLocalAgentConnectionTimesOut() async {
            let now = Date.now
            let tomorrow = now.addingTimeInterval(.days(1))

            let mockVPNSession = VPNSessionMock(status: .disconnected)
            let mockManager = MockTunnelManager(connection: mockVPNSession)
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { features }
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            // Fast forward to the exact time at which the connection should time out
            await mockClock.advance(by: .seconds(29)) // Default timeout minus time spent connecting tunnel (1s)
            await store.receive(\.timeout)
            await store.receive(\.disconnect.connectionFailure.timeout.connectingToLocalAgentServer)
            await store.receive(\.delegate.error.timeout.connectingToLocalAgentServer)
            await store.receive(\.tunnel.disconnect)
            await store.receive(stateChange(from: \.connecting, to: \.disconnecting))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// When path becomes satisfied (e.g. after being unsatisfied or WiFi ↔ cellular), the reducer
        /// disconnects and reconnects the Local Agent TCP. This reconnect only runs when
        /// `shouldAttemptConnection` changes (e.g. unsatisfied → satisfied);
        /// requiresConnection → satisfied does not change that flag so we set up unsatisfied → satisfied in this test.
        @Test
        @MainActor
        func reconnectsLocalAgentProactivelyWhenConnectivityBecomesSatisfied() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.vpnAuthenticationStorage = mockStorage
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Now we're in a fully connected state. Simulate network path change from unsatisfied to satisfied

            // TODO: ProTUN, Revisit
//            // First, send unsatisfied status
//            await store.send(.connectivityChanged(.unsatisfied)) {
//                $0.currentNwStatus = .unsatisfied
//            }
//
//            // Now trigger the satisfied status change - this should trigger proactive reconnection
//            await store.send(.connectivityChanged(.satisfied)) {
//                $0.currentNwStatus = .satisfied
//            }

            // The reducer should:
            // 1. Send connectivityChanged(true) to local agent
            // 2. Disconnect the local agent
            // 3. Wait 150ms
            // 4. Reconnect with the same endpoint and auth data

            await store.receive(stateChange(from: \.connected, to: \.disconnecting))

            await mockClock.advance(by: .milliseconds(150))

            await store.receive(stateChange(from: \.disconnecting, to: \.connecting))

            await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to reconnect
            await store.receive(stateChange(from: \.connecting, to: \.connected))

            // Disconnect before stopping observations
            await performDisconnection(store: store, clock: mockClock)

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// Test that we do not get stuck in a `disconnecting` state if we received a Local Agent error before we are able
        /// to establish the connection
        @Test
        @MainActor
        func disconnectsSuccessfullyAfterReceivingLocalAgentErrorDuringConnection() async {
            let now = Date()
            let tomorrow = now.addingTimeInterval(.days(1))
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
            let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
            let features = VPNConnectionFeatures.mock
            let mockStorage = VpnAuthenticationStorage.testStorage(
                keys: mockKeys,
                certificate: mockCertificate,
                features: features
            )

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let server = Server.mock
            let tunnelSettings = TunnelSettings.mock
            let connectedServerID = server.endpoint.id

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.vpnAuthenticationStorage = mockStorage
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.connectionFeatureProvider.connectionFeatures = { .mock }
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
                $0.tunnel = .connecting
            }
            await store.receive(stateChange(from: \.disconnected, to: \.starting))

            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
            await store.receive(\.tunnel.tunnelStatusChanged.connected) {
                $0.tunnel = .connected(.wireGuard(.go), ConnectionData(serverID: connectedServerID, connectionDate: now, protocolData: .wireGuardGo))
            }
            await store.receive(stateChange(from: \.starting, to: \.connecting))

            await store.receive(\.tunnel.disconnect)
            await store.receive(stateChange(from: \.connecting, to: \.disconnecting))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }

            await mockClock.advance(by: .milliseconds(250))

            await mockClock.advance(by: .milliseconds(750))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// Resilience test - assert that the feature gracefully handles not receiving the expected tunnel status changes
        /// If this happens in production, we're most likely not correctly subscribed to tunnel status notifications.
        @Test
        @MainActor
        func connectionTimesOutWithStartErrorIfTunnelStartRequestSucceedsButExtensionDoesNotStartConnecting() async {
            let mockSession = VPNSessionMock(status: .disconnected)
            mockSession.startupDuration = .seconds(60) // Tunnel should not enter .connecting state before connection timeout
            let mockManager = MockTunnelManager(connection: mockSession)
            let mockClock = TestClock()

            let server = Server.mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock

            let disconnected = CoreConnectionFeature.State(tunnelState: .disconnected)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
                    ._printChanges()
            } withDependencies: {
                $0.date = .constant(.now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.vpnKeysGenerator = VPNKeysGenerator(generateKeys: { .mock() })
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)
            await store.receive(\.tunnel.tunnelStartRequestFinished.success)

            // Now, we would normally receive an `.tunnelStatusChanged.connecting` event.
            // Let's verify that if this does not happen, we do not get stuck in a connecting/disconnecting state forever.

            await mockClock.advance(by: .seconds(30)) // Fast foward until we should be timing out the connection

            #expect(mockSession.status == .disconnected)
            await store.receive(\.timeout)
            await store.receive(\.disconnect.connectionFailure.timeout.tunnel.start)
            await store.receive(\.delegate.error.timeout.tunnel.start)

            await store.receive(\.tunnel.disconnect)

            await mockClock.advance(by: .milliseconds(250))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        /// In order to save the VPN configuration for the first time, the user must give permission and enter their
        /// passcode when the system navigates them to the VPN settings. Here we are verifying that we correctly
        /// either of these scenarios:
        ///  - the user takes too long to enter their passcode
        ///  - the system does not present the VPN settings screen/passcode screen
        @Test
        @MainActor
        func connectionTimesOutWithConfigurationErrorIfConfigurationIsNotSavedInTime() async {
            let mockSession = VPNSessionMock(status: .invalid)
            let mockManager = MockTunnelManager(connection: mockSession)
            // We want to block the start task to prevent transitioning into .connecting
            mockManager.tunnelStartDuration = .seconds(60)
            let mockClock = TestClock()

            let server = Server.mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock

            let disconnected = CoreConnectionFeature.State(tunnelState: .invalid)

            let store = TestStore(initialState: disconnected) {
                CoreConnectionFeature()
            } withDependencies: {
                $0.date = .constant(.now)
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.vpnKeysGenerator = VPNKeysGenerator(generateKeys: { .mock() })
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            }

            await store.send(.startObserving)
            await store.receive(\.tunnel.startObserving)

            // Model the VPN as not configured (no configuration saved to VPN settings)
            await store.receive(\.tunnel.tunnelStatusChanged.invalid)

            // Connection

            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.connect(intent))
            await store.receive(\.tunnel.connect)

            // We want to test what happens if the tunnel start task never completes.
            await mockClock.advance(by: .seconds(30)) // Fast foward until we should be timing out the connection

            await store.receive(\.timeout)
            #expect(mockSession.status == .invalid) // Let's verify the tunnel is in the expected state

            // We never configured the tunnel, so we should fail at the configuration stage
            await store.receive(\.disconnect.connectionFailure.timeout.tunnel.configuration)
            await store.receive(\.delegate.error.timeout.tunnel.configuration)

            await store.receive(\.tunnel.disconnect)

            await mockClock.advance(by: .milliseconds(250))

            await store.send(.stopObserving)
            await store.receive(\.tunnel.stopObserving)
        }

        // MARK: - Helper methods

        private func stateChange(
            from _: PartialCaseKeyPath<CoreConnectionState>,
            to _: PartialCaseKeyPath<CoreConnectionState>,
            strict _: Bool = true
        ) -> (CoreConnectionFeature.Action) -> Bool {
            // TODO: ProTUN, Revisit
            { _ in false }
//            stateChangePredicate(
//                from: oldValue,
//                to: newValue,
//                extract: \CoreConnectionFeature.Action.[case: \.delegate.stateChanged],
//                strict: strict
//            )
        }

        /// Helper method to perform a full disconnection sequence
        @MainActor
        private func performDisconnection(
            store: TestStore<CoreConnectionFeature.State, CoreConnectionFeature.Action>,
            clock: TestClock<Duration>,
            reason: CoreConnectionFeature.DisconnectReason = .userIntent
        ) async {
            await store.send(.disconnect(reason))
            await store.receive(\.tunnel.disconnect)
            await store.receive(stateChange(from: \.connected, to: \.disconnecting))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnecting) {
                $0.tunnel = .disconnecting(nil)
            }

            await clock.advance(by: .milliseconds(250))

            await clock.advance(by: .milliseconds(750))
            await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
                $0.tunnel = .disconnected(nil)
            }
            await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))
        }
    }

    extension ExtensionFeature.State {
        static let disconnected: Self = .disconnected(nil)
    }
#endif
