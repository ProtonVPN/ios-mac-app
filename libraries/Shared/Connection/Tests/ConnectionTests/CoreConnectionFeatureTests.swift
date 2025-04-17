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
import VPNShared
import VPNSharedTesting

import CoreConnection
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
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

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
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
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
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Disconnection

        await store.send(.disconnect(.userIntent))
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

    /// Tests how we handle an edge case where the API refuses to refresh our certificate due to key conflict.
    /// We have to purge our locally stored keys and interrupt the connetion process (since the tunnel will need to
    /// be reconnected with a new private key).
    @MainActor func testDisconnectsWithErrorWhenCertificateAuthenticationFailsDueToKeyConflict() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let localAgent = LocalAgentMock(state: .disconnected)
        let mockClock = TestClock()
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
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
                refreshCertificate: { .requiresNewKeys }, // Simulate a 409 error (VPNAPPL-2757)
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

    @MainActor func testDisconnectsWithErrorWhenUnrecoverableLocalAgentErrorReceived() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

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
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
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
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting
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
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate)),
            localAgentState: .disconnected(.agentError(.policyViolationDelinquent))
        )
        XCTAssertEqual(store.state, disconnectedWithPolicyViolationDelinquent)
    }

    @MainActor func testRefreshesCertificateWhenLocalAgentReceivesCertificateExpiredErrorEvent() async {
        let now = Date.now
        let tomorrow = now.addingTimeInterval(.days(1))
        let dayAfterTomorrow = tomorrow.addingTimeInterval(.days(1))

        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: dayAfterTomorrow, refreshTime: dayAfterTomorrow)
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate)),
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
            $0.certificateRefreshClient = .init(
                refreshCertificate: {
                    mockStorage.cert = refreshedCertificate
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
            $0.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Certificate expiration

        store.dependencies.date = .constant(tomorrow.addingTimeInterval(.minutes(1)))

        await store.send(.localAgent(.event(.error(.certificateExpired)))) // Subscription ran out
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
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)

        // Reconnect with refreshed certificate

        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting
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
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate)),
            localAgentState: .connected(nil)
        )
        XCTAssertEqual(store.state, connectedWithRefreshedCertificate)

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    /// Similar to `testRefreshesCertificateWhenLocalAgentReceivesCertificateExpiredErrorEvent`, with the main
    /// difference being the mechanism through which Local Agent reports the certificate needing to be refreshed.
    /// In this test, it's through entering one of the error states, rather than explicitly receiving an error.
    @MainActor func testRefreshesCertificateWhenLocalAgentEntersCertificateExpiredState() async {
        let now = Date.now
        let tomorrow = now.addingTimeInterval(.days(1))
        let dayAfterTomorrow = tomorrow.addingTimeInterval(.days(1))

        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)
        let mockStorage = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: dayAfterTomorrow, refreshTime: dayAfterTomorrow)
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate)),
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
            $0.certificateRefreshClient = .init(
                refreshCertificate: {
                    mockStorage.cert = refreshedCertificate
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
            $0.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }
        await store.receive(stateChange(from: \.connecting, to: \.connected))

        // Certificate expiration

        store.dependencies.date = .constant(tomorrow.addingTimeInterval(.minutes(1)))

        await store.send(.localAgent(.event(.state(.clientCertificateError)))) // Subscription ran out
        await store.receive(\.localAgent.delegate.certificateRefreshRequired.clientCertificateError)
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
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)

        // Reconnect with refreshed certificate

        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting
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
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: refreshedCertificate)),
            localAgentState: .connected(nil)
        )
        XCTAssertEqual(store.state, connectedWithRefreshedCertificate)

        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopAllObservations)
    }

    @MainActor func testDisconnectsWithTimeoutErrorWhenConnectionTimesOut() async {
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
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

        mockManager.connection = VPNSessionMock(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let server = Server.mock
        let features = VPNConnectionFeatures.mock
        let tunnelSettings = TunnelSettings.mock
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = CoreConnectionFeature.State.init(
            tunnelState: .disconnected(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate)),
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
            $0.localAgent = .connecting
        }

        // Fast forward to the exact time at which the connection should time out
        await mockClock.advance(by: .seconds(29)) // Default timeout minus time spent connecting tunnel (1s)
        await store.receive(\.disconnect.connectionFailure.timeout)
        await store.receive(\.delegate.error.timeout)
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
        mockStorage.keys = mockKeys
        mockStorage.cert = mockCertificate

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
            $0.certificateRefreshClient = .init(refreshCertificate: { .ok }, pushSelector: { })
            $0.vpnAuthenticationStorage = mockStorage
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
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect)
        await store.receive(\.localAgent.startNetShieldStatsObservation)
        await store.receive(\.localAgent.event.state.connecting) {
            $0.localAgent = .connecting
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
        await store.receive(\.disconnect.connectionFailure.timeout)
        await store.receive(\.delegate.error.timeout)

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
