//
//  Created on 30/04/2024.
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

import ComposableArchitecture
@testable import Connection
@testable import ExtensionManager
@testable import tvOS
import XCTest

import DomainTestSupport
@testable import LocalAgent
import PersistenceTestSupport

final class MainFeatureTests: XCTestCase {
    @MainActor
    func testTabSelection() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.selectTab(.settings)) {
            $0.currentTab = .settings
            $0.$mainBackground.withLock { $0 = .clear }
        }
        await store.receive(\.settings.tabSelected)
        await store.send(.selectTab(.home)) {
            $0.currentTab = .home
            $0.$mainBackground.withLock { $0 = .connecting }
        }
    }

    @MainActor
    func testSettingsContactUs() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.settings(.showDrillDown(.contactUs))) {
            $0.settings.destination = .settingsDrillDown(.dynamic(.contactUs))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
    }

    @MainActor
    func testErrorConnectingNotifiesError() async {
        let clock = TestClock()
        let mockVPNSession = VPNSessionMock(status: .disconnected)
        let store = TestStore(initialState: MainFeature.State(homeLoading: .loaded(.init()))) {
            MainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
            $0.continuousClock = clock
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
            $0.userLocationService = UserLocationServiceMock()
        }
        store.exhaustivity = .off
        await store.send(.connection(.delegate(.connectionFailed(.serverMissing))))
        await store.receive(\.errorOccurred)
        await clock.advance(by: .seconds(1))
    }

    @MainActor
    func testUserClickedConnect() async {
        let clock = TestClock()
        let mockVPNSession = VPNSessionMock(status: .disconnected)

        var connectionFeatureState = ConnectionFeature.State.initialState
        connectionFeatureState.core = .init(tunnelState: .disconnected(nil))
        // ServerListFeature.State uses ServerRepository in its constructor. It's not explicitly necessary to override
        // it here, since TestStore accepts an autoclosure argument which is executed with overridden dependencies.
        let store = TestStore(initialState: MainFeature.State(homeLoading: .loaded(.init()), connection: connectionFeatureState)) {
            MainFeature()
        } withDependencies: {
            $0.serverIdentifier = .init(fullServerInfo: { _ in nil })
            $0.serverRepository = .notEmpty()
            $0.continuousClock = clock
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
            $0.smartPortSelector = .init(select: { _, _ in .init(chosenProtocol: .wireGuard(.udp), ports: [80]) })
            $0.connectionIntentStorage = .init(
                getConnectionIntent: { .init(spec: .defaultFastest, server: .mock, tunnelSettings: .mock, features: .mock) },
                set: { _ in }
            )
        }
        @Shared(.connectionState) var connectionState: ConnectionState

        store.exhaustivity = .off(showSkippedAssertions: true)

        $connectionState.withLock { $0 = .disconnected }
        await store.send(.homeLoading(.loaded(.protectionStatus(.delegate(.userClickedConnect)))))
        await store.receive(\.connectDisconnectingIfNecessary)
    }
}
