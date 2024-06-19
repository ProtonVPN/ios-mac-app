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

import struct ConnectionFoundations.LogicalServerInfo

@testable import ExtensionManager
@testable import LocalAgent
@testable import Connection
@testable import LocalAgentTestSupport

final class ConnectionFeatureTests: XCTestCase {
   
    /// Happy path test. Uses mocked dependencies to verify that the `ExtensionManagerFeature` and `LocalAgentFeature`
    /// reducers are correctly stitched together by the `ConnectionFeature` reducer.
    @MainActor func testEndToEndConnection() async {
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()
        let mockAgent = LocalAgentMock(state: .disconnected)

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
            $0.certificateAuthentication = .init(
                loadAuthenticationData: { _ in .empty }
            )
        }

        await store.send(.tunnel(.startObservingStateChanges))
        await store.receive(\.tunnel.tunnelStatusChanged.disconnected)

        await store.send(.localAgent(.startObservingEvents))

        // Connection

        await store.send(.connect(server, features))
        await store.receive(\.tunnel.connect) {
            $0.tunnel = .connecting
        }
        await store.receive(\.tunnel.tunnelStartRequestFinished.success)
        await store.receive(\.tunnel.tunnelStatusChanged.connecting)

        await mockClock.advance(by: .seconds(1)) // Give MockVPNSession time to establish connection
        await store.receive(\.tunnel.tunnelStatusChanged.connected)
        await store.receive(\.tunnel.connectionFinished.success) {
            $0.tunnel = .connected(connectedLogicalServer)
        }
        await store.receive(\.localAgent.connect) {
            $0.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.localAgent.connectionFinished.success){
            $0.localAgent = .connected
        }
        await store.receive(\.localAgent.event.state.connected)

        let expectedConnectedState = ConnectionFeature.State(tunnelState: .connected(connectedLogicalServer), localAgentState: .connected)
        XCTAssertEqual(store.state, expectedConnectedState)

        // Disconnection

        await store.send(ConnectionFeature.Action.disconnect(nil))
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

        XCTAssertEqual(store.state, disconnected, "Sanity check - whether we are fully disconnected")

        await store.send(.tunnel(.stopObservingStateChanges))
        await store.send(.localAgent(.stopObservingEvents))
    }
}
#endif
