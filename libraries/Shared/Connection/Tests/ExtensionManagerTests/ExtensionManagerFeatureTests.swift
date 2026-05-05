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
    import XCTest

    final class ExtensionManagerFeatureTests: XCTestCase {
        @MainActor
        func testRequestsTunnelStart() async {
            let mockManager = MockTunnelManager()
            let mockClock = TestClock()

            let server = Server.ca // Canadian server mock
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)
            let now = Date.now

            mockManager.connection = VPNSessionMock(
                status: .disconnected,
                connectedDate: nil,
                lastDisconnectError: nil
            )

            let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                ExtensionFeature()
            } withDependencies: {
                $0.continuousClock = mockClock
                $0.tunnelManager = mockManager
                $0.date = .constant(now)
            }

            await store.send(.startObservingStateChanges)
            await store.receive(\.tunnelStatusChanged.disconnected)

            await store.send(.connect(intent))
            await store.receive(\.tunnelStatusChanged.connecting) {
                $0 = .connecting
            }

            await store.receive(\.tunnelStartRequestFinished.success)

            await store.send(.stopObservingStateChanges)
        }

        @MainActor
        func testStateSetToConnectedIfExistingTunnelIsConnected() async {
            let mockManager = MockTunnelManager()
            mockManager.connection = VPNSessionMock(
                status: .connected,
                connectedDate: nil,
                lastDisconnectError: nil
            )
            mockManager.connection.connectedServerID = "previousServerID"
            let now = Date.now

            let expectedConnectionData = ConnectionData(serverID: "previousServerID", connectionDate: now, protocolData: .wireGuardGo)

            let store = TestStore(initialState: TunnelState.disconnected(nil)) {
                ExtensionFeature()
            } withDependencies: {
                $0.tunnelManager = mockManager
                $0.date = .constant(now)
            }

            await store.send(.startObservingStateChanges)
            await store.receive(\.tunnelStatusChanged.connected) {
                $0 = .connected(.wireGuard(.go), expectedConnectionData)
            }

            await store.send(.stopObservingStateChanges)
        }

        @MainActor
        func testDisconnectsWhenVPNConfigurationPermissionDenied() async {
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
            let features = VPNConnectionFeatures.mock
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: server, protocolConfiguration: .wireGuard(tunnelSettings), features: features)

            await store.send(.startObservingStateChanges)
            await store.receive(\.tunnelStatusChanged.invalid) {
                $0 = .invalid
            }

            let permissionDenied: Error = "NEVPNErrorDomain Code=5 permission denied" as GenericError
            mockManager.tunnelStartErrorToThrow = permissionDenied

            await store.send(.connect(intent))
            await store.receive(\.tunnelStartRequestFinished.failure) {
                $0 = .disconnected(.tunnelStartFailed(permissionDenied))
            }

            await store.send(.stopObservingStateChanges)
        }
    }
#endif
