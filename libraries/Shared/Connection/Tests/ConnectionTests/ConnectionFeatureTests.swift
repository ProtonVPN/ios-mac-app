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
import Clocks
import ComposableArchitecture

import Domain
import DomainTestSupport
import VPNShared
import VPNSharedTesting

import CoreConnection
import CoreConnectionTestSupport
@testable import ExtensionManager
@testable import CertificateAuthentication
@testable import LocalAgent
@testable import Connection

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
        let initialIntent = ServerConnectionIntent.mock(withRegionCode: "US")
        let reconnectionSpec = ConnectionSpec(location: .region(code: "CA"), features: [])
        let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec, server: server)
        let preparedReconnectionIntent = ServerConnectionIntent.mock(
            withRegionCode: "CA",
            server: server,
            tunnelSettings: .init(transport: .tls, ports: [420], features: .unimplementedFeatures),
            features: connectionFeatures
        )

        let coreState = CoreConnectionFeature.State.init(
            tunnelState: .disconnecting(nil),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: keys), certificate: certificate)),
            localAgentState: .disconnected(nil)
        )
        let initialState = ConnectionFeature.State(
            connectionState: .disconnecting(initialIntent, .mock),
            currentIntent: initialIntent,
            queuedIntent: nil,
            core: coreState
        )

        let store = TestStore(initialState: initialState) {
            ConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.certificateRefreshClient = .init(refreshCertificate: { .ok }, pushSelector: { })
            $0.vpnAuthenticationStorage = mockStorage
            $0.localAgent = mockAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.connectionIntentStorage = .init(getConnectionIntent: { initialIntent }, set: { _ in })
            $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
            $0.smartPortSelector.select = { _, _ in
                portSelectionExpectation.fulfill()
                return ServerEndpointPortResolution(chosenProtocol: .wireGuard(.tls), ports: [420])
            }
        }

        await store.send(.input(.onLaunch))
        await store.receive(\.core.startObserving)
        await store.receive(\.core.tunnel.startObservingStateChanges)
        await store.receive(\.core.localAgent.startObservingEvents)
        await store.receive(\.core.tunnel.tunnelStatusChanged.disconnecting)

        // Connection feature is in the 'disconnecting' state, now let's send a connection request
        await store.send(.input(.connect(reconnectionPreparationIntent))) {
            $0.queuedIntent = reconnectionPreparationIntent
        }

        mockVPNSession.status = .disconnected // Simulate the disconnection attempt finishing
        await store.receive(\.core.tunnel.tunnelStatusChanged.disconnected) {
            $0.core.tunnel = .disconnected(nil)
        }
        await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected)) {
            $0.queuedIntent = nil
        }

        // We've finally disconnected, so it's now sensible to start port/protocol selection
        // Now that we are fully disconnected, the queued connection attempts should immediately start
        await store.receive(\.prepare)
        await store.receive(\.startConnection) {
            $0.currentIntent = preparedReconnectionIntent
        }

        await fulfillment(of: [portSelectionExpectation], timeout: 0) // Let's verify port selection occurred before connection
        await store.receive(\.core.connect)
        await store.receive(\.core.tunnel.connect) {
            $0.core.tunnel = .preparingConnection(reconnectingServerInfo)
        }
        await store.receive(coreStateChange(from: \.disconnected, to: \.starting))
        await store.receive(stateChange(to: \.connecting))

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
            $0.core.localAgent = .connecting
        }

        await mockClock.advance(by: .seconds(1)) // give LocalAgentMock time to connect
        await store.receive(\.core.localAgent.event.state.connected) {
            $0.core.localAgent = .connected(nil)
        }
        await store.receive(coreStateChange(from: \.connecting, to: \.connected))
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
        let initialIntent = ServerConnectionIntent.mock(withRegionCode: "US")

        let serverToReconnectTo = Server.ca
        let reconnectionSpec = ConnectionSpec(location: .region(code: "CA"), features: [])
        let reconnectionPreparationIntent = ConnectionPreparationIntent(spec: reconnectionSpec, server: serverToReconnectTo)
        let preparedReconnectionIntent = ServerConnectionIntent.mock(
            withRegionCode: "CA",
            server: serverToReconnectTo,
            tunnelSettings: .init(transport: .tls, ports: [420], features: .unimplementedFeatures),
            features: connectionFeatures
        )

        // Because of the initial value we observe in `ExtensionFeature.Action.startObservingStateChanges`, we can't fully
        // accurately model starting a reducer in the fully connected state yet.
        // It's not a problem, since we always start from the resolving state when running in the app.
        let coreState = CoreConnectionFeature.State.init(
            tunnelState: .connecting(initialServerInfo),
            certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: keys), certificate: certificate)),
            localAgentState: .disconnected(nil)
        )
        let initialState = ConnectionFeature.State(connectionState: .resolving, currentIntent: nil, queuedIntent: nil, core: coreState)

        let store = TestStore(initialState: initialState) {
            ConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.certificateRefreshClient = .init(refreshCertificate: { .ok }, pushSelector: { })
            $0.vpnAuthenticationStorage = mockStorage
            $0.localAgent = mockAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.connectionIntentStorage = .init(getConnectionIntent: { initialIntent }, set: { _ in })
            $0.connectionFeatureProvider.connectionFeatures = { connectionFeatures }
            $0.smartPortSelector.select = { _, _ in
                portSelectionExpectation.fulfill()
                return ServerEndpointPortResolution(chosenProtocol: .wireGuard(.tls), ports: [420])
            }
        }

        // Let's skip repeating assertions we've covered in previous tests
        store.exhaustivity = .off
        await store.send(.input(.onLaunch))
        await mockClock.advance(by: .seconds(2))
        await store.receive(stateChange(to: \.connected))

        // Connection feature is in the 'connected' state, now let's send a connection request
        await store.send(.input(.connect(reconnectionPreparationIntent))) {
            $0.queuedIntent = reconnectionPreparationIntent
        }
        await store.receive(\.core.disconnect)
        await mockClock.advance(by: .seconds(1))
        await store.receive(coreStateChange(from: \.connected, to: \.disconnecting))
        await store.receive(stateChange(to: \.connecting))
        await store.receive(coreStateChange(from: \.disconnecting, to: \.disconnected))

        // We've finally disconnected, so it's now sensible to start port/protocol selection
        // Now that we are fully disconnected, the queued connection attempts should immediately start
        await store.receive(\.prepare)
        await store.receive(\.startConnection) {
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

    @MainActor func testConnectionStateResolvesToDisconnected() async {
        let mockVPNSession = VPNSessionMock(status: .disconnected, connectedDate: nil, lastDisconnectError: nil)
        let mockManager = MockTunnelManager(connection: mockVPNSession)
        let mockAgent = LocalAgentMock(state: .disconnected)


        let store = TestStore(initialState: .init()) {
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

        let store = TestStore(initialState: .init()) {
            ConnectionFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.localAgent = mockAgent
            $0.vpnAuthenticationStorage = mockStorage
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.connectionIntentStorage = .init(getConnectionIntent: { .mock(withRegionCode: "EU") }, set: { _ in })
        }

        store.exhaustivity = .off
        await store.send(.input(.onLaunch))
        await mockClock.advance(by: .seconds(2))
        await store.receive(coreStateChange(from: \.unknown, to: \.starting))
        await store.receive(coreStateChange(from: \.starting, to: \.connecting))
        await store.receive(coreStateChange(from: \.connecting, to: \.connected))
        await store.receive(stateChange(to: \.connected))
    }

    func stateChange(to expectedState: PartialCaseKeyPath<ConnectionState>) -> (ConnectionFeature.Action) -> Bool {
        return { action in
            guard case .delegate(.stateChanged(let state)) = action else {
                return false
            }
            if state.is(expectedState) {
                return true
            }
            XCTFail("Received state change action, but to the incorrect state")
            return false
        }
    }

    func coreStateChange(
        from oldValue: PartialCaseKeyPath<CoreConnectionState>,
        to newValue: PartialCaseKeyPath<CoreConnectionState>
    ) -> (ConnectionFeature.Action) -> Bool {
        return { action in
            guard case .core(.delegate(.stateChanged(let oldState, let newState))) = action else {
                return false
            }
            if oldState.is(oldValue) && newState.is(newValue) {
                return true
            }
            XCTFail("Received core state change action, but between incorrect states")
            return false
        }
    }
}
#endif
