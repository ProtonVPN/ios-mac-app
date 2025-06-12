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

#if targetEnvironment(simulator) // MockTunnelManager is only built for the simulator
import XCTest
import Clocks
import ComposableArchitecture

import Domain
import DomainTestSupport
import Ergonomics
import ExtensionIPC
import VPNShared
import VPNSharedTesting

@testable import CoreConnection
import CoreConnectionTestSupport
import ConnectionTestSupport
@testable import ExtensionManager
@testable import CertificateAuthentication
@testable import LocalAgent
@testable import Connection

final class CoreConnectionFeatureTests: XCTestCase {
    /// Happy path test. Uses mocked dependencies to verify that the `ExtensionManagerFeature` and `LocalAgentFeature`
    /// reducers are correctly stitched together by the `ConnectionFeature` reducer.
    @MainActor func testEndToEndConnection() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let features = VPNConnectionFeatures.mock
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Disconnection

        await store.send(.disconnect(.userIntent))
        await store.receive(\.certAuth.cancelRefreshes)
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnecting(nil)
        }
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }
        await store.receive(stateChange(from: \.connected, to: \.disconnecting))

        await mockClock.advance(by: .milliseconds(250))
        await store.receive(\.localAgent.event.state.disconnected) {
            $0.localAgent = .disconnected(nil)
        }
        await mockClock.advance(by: .milliseconds(750))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))
        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// This test ensures that if the network extension is stopped while the certificate refresh process is active, we
    /// cancel any in-flight certificate refresh effects that would otherwise retry sending IPC messages to the
    /// extension after the tunnel is stopped, resulting in extra UNEX or TNAB errors after disconnecting.
    @MainActor func testCancelsCertificateRefreshEffectsWhenConnectionIsAborted() async {
        let now = Date.now
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()

        let mockStorage = MockVpnAuthenticationStorage().with(keys: .constantKeys)

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
            $0.localAgent = LocalAgentMock(state: .disconnected)

            // We want to test the real implementation of the cert refresh client in this test
            $0.certificateRefreshClient = .liveValue

            // Let's control the lower level tunnel message sender instead
            $0.tunnelMessageSender.send = { message in
                XCTAssertEqual(message, .refreshCertificate(features: .mock), "Expected cert refresh client to ask for refresh")

                // Let's model a scenario where the cert refresh takes a long time because of poor network conditions.
                // If the tunnel is stopped before it can respond to our message, the completion handler app-side will
                // still be invoked, so it's important to verify that the task is cancelled so we don't retry sending
                // messages.
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: .seconds(45))

                // After 45 seconds, the connection attempt should have been aborted, and therefore this task should have been cancelled.
                if Task.isCancelled {
                    throw ProviderMessageError.cancelled
                } else {
                    XCTFail("Expected task to have been cancelled")
                    return .ok(data: nil)
                }
            }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: .mock)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.certAuth.refreshCertificate)

        // Let's assume the connection attempt times out while the certificate refresh is still in progress
        // In this case, we don't receive a response to our certificate refresh IPC message until the tunnel is killed.
        await mockClock.advance(by: .seconds(30))
        await store.receive(\.timeout)
        await store.receive(\.disconnect.connectionFailure.timeout.refreshingCertificate) // Should cancel the cert-refresh effect
        await store.receive(\.delegate.error.timeout.refreshingCertificate)
        await store.receive(\.certAuth.cancelRefreshes)
        await store.receive(\.localAgent.disconnect)
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.disconnecting))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

        // Advance the clock 30 more seconds just in case an erroneous retry happens
        await mockClock.advance(by: .seconds(30))
        // If we haven't received any additional cert-auth failures by now, then the test was successful.

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// In case the tunnel disconnects for some unexpected reason while we are in the process of loading or refreshing
    /// our certificate, make sure that the connection process is aborted and an error is raised instead of entering
    /// an infinite loop. Possible reasons for the tunnel disconnecting include user actions (turning off VPN via
    /// system UI) or packet tunnel provider process crashes.
    @MainActor func testDisconnectsWithErrorWhenCertificateAuthenticationFinishesButTunnelIsNotConnected() async {
        let now = Date()
        let yesterday = now.addingTimeInterval(.days(-1))
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let localAgent = LocalAgentMock(state: .disconnected)
        let mockClock = TestClock()

        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let oldCertificate = VpnCertificate(certificate: "1234", validUntil: yesterday, refreshTime: yesterday)
        let newCertificate = VpnCertificate(certificate: "5678", validUntil: tomorrow, refreshTime: tomorrow)
        let features = VPNConnectionFeatures(netshield: .off, vpnAccelerator: false, bouncing: nil, natType: .moderateNAT, safeMode: false)
        mockStorage.keys = mockKeys
        mockStorage.cert = oldCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)
        let certRefreshStarted = XCTestExpectation(description: "Cert refresh process should have been started")

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.localAgent = localAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.vpnAuthenticationStorage = mockStorage
            $0.certificateRefreshClient = .init(
                refreshCertificate: { _ in
                    certRefreshStarted.fulfill()
                    @Dependency(\.continuousClock) var clock
                    try await clock.sleep(for: .seconds(2))
                    mockStorage.cert = newCertificate
                    return .ok
                },
                pushSelector: { unimplemented("Unexpected session fork + selector push") }
            )
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.certificateExpired)
        await store.receive(\.certAuth.refreshCertificate)

        // Give some time for the cert refresh process to start
        await mockClock.advance(by: .seconds(1))
        await fulfillment(of: [certRefreshStarted], timeout: 0)

        // Simulate the tunnel crashing or being manually disconnected by the user
        mockManager.connection.status = .disconnected
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.disconnected))

        // Give some more time for the cert refresh process to finish
        await mockClock.advance(by: .seconds(1))
        await store.receive(\.certAuth.refreshFinished.success) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: newCertificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)

        // Now, because the network extension was unexpectly stopped, we should abort the connection process with an error
        await store.receive(\.disconnect.connectionFailure.tunnel.tunnelAborted)
        await store.receive(\.delegate.error.tunnel.tunnelAborted)
        await store.receive(\.certAuth.cancelRefreshes)
        await store.receive(\.localAgent.disconnect)
        await store.receive(\.tunnel.disconnect)

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// In case the tunnel disconnects for some unexpected reason after we have successfully connected, make sure that
    /// Local Agent is disconnected as well.
    /// Possible reasons for the tunnel disconnecting include user actions outside of the app (control centre or
    /// system VPN settings) or packet tunnel provider process crashes.
    @MainActor func testDisconnectsLocalAgentIfTunnelIsStoppedExternally() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let localAgent = LocalAgentMock(state: .disconnected)
        let mockClock = TestClock()

        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let features: VPNConnectionFeatures = .mock
        mockStorage.keys = mockKeys
        mockStorage.cert = certificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)
        let certRefreshStarted = XCTestExpectation(description: "Cert refresh process should have been started")

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.localAgent = localAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { features }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: .mock)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: certificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Simulate the tunnel crashing or being manually disconnected by the user
        mockManager.connection.status = .disconnected
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.connected, to: \.disconnected))

        // Now, because the network extension was unexpectly stopped, we should disconnect from Agent as well
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnecting(nil)
        }

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// Tests how we handle an edge case where the API refuses to refresh our certificate due to key conflict.
    /// We have to purge our locally stored keys and interrupt the connetion process (since the tunnel will need to
    /// be reconnected with a new private key).
    @MainActor func testDisconnectsWithErrorWhenCertificateAuthenticationFailsDueToKeyConflict() async {
        let now = Date()
        let mockManager = MockTunnelManager()
        let localAgent = LocalAgentMock(state: .disconnected)
        let mockClock = TestClock()
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        mockStorage.keys = mockKeys
        mockStorage.cert = nil

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.localAgent = localAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.vpnAuthenticationStorage = mockStorage
            $0.certificateRefreshClient = .init(
                refreshCertificate: { _ in .requiresNewKeys }, // Simulate a 409 error (VPNAPPL-2757)
                pushSelector: { unimplemented("Unexpected session fork + selector push") }
            )
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.certAuth.refreshCertificate)
        await store.receive(\.certAuth.refreshFinished.success.requiresNewKeys) {
            $0.certAuth = .failed(.wontRefresh(.keysMissing))
        }
        await store.receive(\.certAuth.loadingFinished.failure)

        await store.receive(\.disconnect.connectionFailure.certAuth.unexpected)
        await store.receive(\.delegate.error.certAuth.unexpected)
        await store.receive(\.certAuth.cancelRefreshes)
        await store.receive(\.localAgent.disconnect)
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }

        await store.receive(stateChange(from: \.connecting, to: \.disconnecting))

        await mockClock.advance(by: .seconds(1))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    @MainActor func testRegeneratesKeysAndDisconnectsWhenLocalAgentFailsWithGoTLSError() async {
        // Set up a failure to occur while creating the local agent connection
        let localAgent = LocalAgentMock(state: .disconnected)
        let connectionCreationError = LAConnectionCreationError.goTLSError(.privateKeyDoesNotMatchPublicKey, underlyingError: "" as GenericError)
        localAgent.connectionErrorToThrow = connectionCreationError

        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        mockStorage.keys = mockKeys
        mockStorage.cert = certificate
        mockStorage.features = .mock
        mockStorage.keysDeleted = { XCTFail("Keys shouldn't be cleared until we encounter the Go TLS error") }

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()._printChanges()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.localAgent = localAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        let keysCleared = XCTestExpectation(description: "Keys should have been cleared")
        mockStorage.keysDeleted = { keysCleared.fulfill()}

        await mockClock.advance(by: .seconds(1))
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: certificate, features: .mock))
        }
        await store.receive(\.certAuth.loadingFinished.success)

        await store.receive(\.localAgent.connect) {
            $0.localAgent = .disconnected(.failedToEstablishConnection(connectionCreationError))
        }
        await store.receive(\.localAgent.delegate.connectionFailed)
        await store.receive(stateChange(from: \.connecting, to: \.disconnecting))
        await store.receive(\.certAuth.regenerateKeys) {
            $0.certAuth = .idle // Make sure keys are cleared from memory
        }
        await store.receive(\.disconnect)
        await store.receive(\.delegate.error.agent.failedToEstablishConnection)
        await store.receive(\.certAuth.cancelRefreshes)

        await store.receive(\.localAgent.disconnect)
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }

        await fulfillment(of: [keysCleared], timeout: 0) // Make sure keys were also cleared from the keychain

        await mockClock.advance(by: .seconds(1))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    @MainActor func testDisconnectsWithErrorWhenUnrecoverableLocalAgentErrorReceived() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let features = VPNConnectionFeatures.mock
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Encounter an unrecoverable error

        await store.send(.localAgent(.event(.error(.policyViolationDelinquent)))) // Subscription ran out
        await store.receive(\.localAgent.delegate.errorReceived.policyViolationDelinquent)
        await store.receive(\.localAgent.disconnect.agentError.policyViolationDelinquent) {
            $0.localAgent = .disconnecting(.agentError(.policyViolationDelinquent))
        }
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }
        await store.receive(stateChange(from: \.connected, to: \.disconnecting))

        await mockClock.advance(by: .milliseconds(250))
        await store.receive(\.localAgent.event.state.disconnected) {
            $0.localAgent = .disconnected(.agentError(.policyViolationDelinquent))
        }
        await mockClock.advance(by: .milliseconds(750))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)

        // Ensure that the final state post-disconnection contains the error so that it can be shown in the UI
        let disconnectedWithPolicyViolationDelinquent: CoreConnectionFeature.State = .init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features)),
            localAgentState: .disconnected(.agentError(.policyViolationDelinquent))
        )
        XCTAssertEqual(store.state, disconnectedWithPolicyViolationDelinquent)
    }

    @MainActor func testRefreshesCertificateWhenLocalAgentReceivesCertificateExpiredErrorEvent() async {
        let now = Date.now
        let laterToday = now.addingTimeInterval(.hours(12))
        let tomorrow = now.addingTimeInterval(.days(1))
        let dayAfterTomorrow = tomorrow.addingTimeInterval(.days(1))

        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: dayAfterTomorrow, refreshTime: dayAfterTomorrow)
        let features = VPNConnectionFeatures.mock
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features)),
            localAgentState: .disconnected(nil)
        )

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { features }
            $0.certificateRefreshClient = .init(
                refreshCertificate: { features in
                    mockStorage.cert = refreshedCertificate
                    mockStorage.features = features
                    return .ok
                },
                pushSelector: { }
            )
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))
        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData)
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Certificate expiration

        // Let's first make sure that we don't disconnect from LA and refresh our certificate if it's still valid
        store.dependencies.date = .constant(laterToday) // certificate doesn't expire until tomorrow
        await store.send(.localAgent(.event(.error(.certificateExpired))))
        await store.receive(\.localAgent.delegate.errorReceived.certificateExpired)
        // We received the error, but should ignore it to avoid entering a disconnect/reconnect loop with the same cert

        // Let's fast forward until our certificate has actually expired
        store.dependencies.date = .constant(tomorrow.addingTimeInterval(.minutes(1)))

        await store.send(.localAgent(.event(.error(.certificateExpired))))
        await store.receive(\.localAgent.delegate.errorReceived.certificateExpired)
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnecting(nil)
        }

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        // The next state change is unfortunate. Maybe we need to add a flag: disconnecting(reconnecting: Bool)
        await store.receive(stateChange(from: \.connected, to: \.disconnecting))
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.certificateExpired)
        await store.receive(\.certAuth.refreshCertificate)
        await store.receive(\.certAuth.refreshFinished) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)

        // Reconnect with refreshed certificate

        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.connecting))

        await mockClock.advance(by: .milliseconds(500))
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)

        let connectedWithRefreshedCertificate: CoreConnectionFeature.State = .init(
            tunnelState: .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now)),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate, features: features)),
            localAgentState: .connected(nil)
        )
        XCTAssertEqual(store.state, connectedWithRefreshedCertificate)

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    @MainActor func testDisconnectsWithTimeoutErrorWhenLocalAgentConnectionTimesOut() async {
        let now = Date.now
        let tomorrow = now.addingTimeInterval(.days(1))

        let mockVPNSession = VPNSessionMock(status: .disconnected)
        let mockManager = MockTunnelManager(connection: mockVPNSession)
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        mockAgent.connectionDuration = .seconds(45) // Longer than our default connection timeout of 30 seconds

        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let features = VPNConnectionFeatures.mock
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features)),
            localAgentState: .disconnected(nil)
        )

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { features }
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData)
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        // Fast forward to the exact time at which the connection should time out
        await mockClock.advance(by: .seconds(29)) // Default timeout minus time spent connecting tunnel (1s)
        await store.receive(\.timeout)
        await store.receive(\.disconnect.connectionFailure.timeout.connectingToLocalAgentServer)
        await store.receive(\.delegate.error.timeout.connectingToLocalAgentServer)
        await store.receive(\.certAuth.cancelRefreshes)
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnecting(nil)
        }
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.disconnecting))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// Test that we do not get stuck in a `disconnecting` state if we received a Local Agent error before we are able
    /// to establish the connection
    @MainActor func testDisconnectsSuccessfullyAfterReceivingLocalAgentErrorDuringConnection() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let features = VPNConnectionFeatures.mock
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate
        mockStorage.features = features

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.certificateRefreshClient = .init(refreshCertificate: { _ in .ok }, pushSelector: { })
            $0.vpnAuthenticationStorage = mockStorage
            $0.localAgent = mockAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(TunnelConnectionResponse(logicalInfo: connectedLogicalServer, connectionDate: now))
        }
        await store.receive(stateChange(from: \.starting, to: \.connecting))

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: features))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting(nil)
        }

        // Let's simulate a max sessions error being received before we are able to finish connecting
        mockAgent.streamTuple?.continuation.yield(.error(.maxSessionsPro))
        mockAgent.connectionTask?.cancel()

        await store.receive(\.localAgent.event.error.maxSessionsPro)
        await store.receive(\.localAgent.delegate.errorReceived.maxSessionsPro)
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnecting(.agentError(.maxSessionsPro))
        }
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.disconnecting))

        await mockClock.advance(by: .milliseconds(250))
        await store.receive(\.localAgent.event.state.disconnected) {
            $0.localAgent = .disconnected(.agentError(.maxSessionsPro))
        }
        await mockClock.advance(by: .milliseconds(750))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.disconnecting, to: \.disconnected))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// Resilience test - assert that the feature gracefully handles not receiving the expected tunnel status changes
    @MainActor func testConnectionTimesOutIfTunnelStartRequestSucceedsButExtensionDoesNotStartConnecting() async {
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockSession = VPNSessionMock(status: .disconnected)
        mockSession.startupDuration = .seconds(60) // Tunnel should not enter .connecting state before connection timeout
        let mockManager = MockTunnelManager(connection: mockSession)
        let mockClock = TestClock()

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            CoreConnectionFeature()
        } withDependencies: {
            $0.date = .constant(.now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.vpnKeysGenerator = VPNKeysGenerator(generateKeys: { .mock() })
            $0.localAgent = mockAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
        }

        await store.send(.startObserving)
        await store.receive(\.tunnel.startObservingStateChanges)
        await store.receive(\.localAgent.startObservingEvents)

        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        // Connection

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, tunnelSettings: tunnelSettings, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .preparingConnection(connectedLogicalServer)
        }
        await store.receive(stateChange(from: \.disconnected, to: \.starting))

        await store.receive(\.tunnel.tunnelStartRequestFinished.success)

        // Now, we would normally receive an `.tunnelStatusChanged.connecting` event.
        // Let's verify that if this does not happen, we do not get stuck in a connecting/disconnecting state forever.

        await mockClock.advance(by: .seconds(30)) // Fast foward until we should be timing out the connection
        await store.receive(\.timeout)
        await store.receive(\.disconnect.connectionFailure.timeout.tunnelStartingAndConnecting)
        await store.receive(\.delegate.error.timeout.tunnelStartingAndConnecting)
        await store.receive(\.certAuth.cancelRefreshes)

        await store.receive(\.localAgent.disconnect)
        await store.receive(\.tunnel.disconnect) {
            // If we never started the tunnel, we should transition straight away into .disconnected
            $0.tunnel = .disconnected(nil)
        }
        await store.receive(stateChange(from: \.starting, to: \.disconnected))

        await mockClock.advance(by: .milliseconds(250))

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    private func stateChange(
        from oldValue: PartialCaseKeyPath<CoreConnectionState>,
        to newValue: PartialCaseKeyPath<CoreConnectionState>,
        strict: Bool = true
    ) -> (CoreConnectionFeature.Action) -> Bool {
        return stateChangePredicate(
            from: oldValue,
            to: newValue,
            extract: \CoreConnectionFeature.Action.[case: \.delegate.stateChanged],
            strict: strict
        )
    }
}
#endif
