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
import ComposableArchitecture

import Domain
import DomainTestSupport
import struct VPNShared.VpnKeys
import struct VPNShared.VpnCertificate
import VPNSharedTesting

import ConnectionFoundations
@testable import ExtensionManager
@testable import CertificateAuthentication
@testable import LocalAgent
@testable import Connection

final class ConnectionFeatureTests: XCTestCase {
   
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
        let connectedLogicalServer = LogicalServerInfo(logicalID: server.logical.id, serverID: server.endpoint.id)

        let disconnected = ConnectionFeature.State.init(tunnelState: .disconnected(nil), localAgentState: .disconnected(nil))

        let store = TestStore(initialState: disconnected) {
            ConnectionFeature()
        } withDependencies: {
            $0.date = .constant(.now)
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

        let intent = ServerConnectionIntent(server: server, transport: .udp, features: features)

        await store.send(.connect(intent))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .connecting(connectedLogicalServer)
        }
        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting)

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(connectedLogicalServer)
        }

        await store.receive(\.certAuth.loadAuthenticationData) {
            $0.certAuth = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.certAuth.loadFromStorage)
        await store.receive(\.certAuth.loadingFromStorageFinished.loaded) {
            $0.certAuth = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.certAuth.loadingFinished.success)
        await store.receive(\.localAgent.connect) {
            $0.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.event.state.connected) {
            $0.localAgent = .connected(nil)
        }

        // Disconnection

        await store.send(ConnectionFeature.Action.disconnect(.userIntent))
        await store.receive(\.localAgent.disconnect) {
            $0.localAgent = .disconnected(nil)
        }
        await store.receive(\.tunnel.disconnect) {
            $0.tunnel = .disconnecting
        }
        await store.receive(\.localAgent.event.state.disconnected)

        await mockClock.advance(by: .seconds(1))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected) {
            $0.tunnel = .disconnected(nil)
        }
        await store.send(.stopObserving)
        await store.receive(\.tunnel.stopObservingStateChanges)
        await store.receive(\.localAgent.stopObservingEvents)
    }
}
#endif
