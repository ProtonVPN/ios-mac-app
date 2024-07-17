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

import XCTest
import ComposableArchitecture
@testable import tvOS
@testable import Connection
@testable import ExtensionManager

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
            $0.mainBackground = .clear
        }
        await store.receive(\.settings.tabSelected)
        await store.send(.selectTab(.home)) {
            $0.currentTab = .home
            $0.mainBackground = .connecting
        }
    }

    @MainActor
    func testSettingsContactUs() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.settings(.showDrillDown(.contactUs))) {
            $0.settings.destination = .settingsDrillDown(.contactUs)
            $0.mainBackground = .settingsDrillDown
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

        await store.send(.connection(.localAgent(.startObservingEvents)))
        await store.send(.connection(.disconnect(.connectionFailure(.serverMissing))))
        await store.receive(\.connection.localAgent.disconnect) {
            $0.connection.localAgent = .disconnecting(nil)
        }
        await store.receive(\.connection.tunnel.disconnect) {
            $0.connection.tunnel = .disconnecting(nil)
        }

        await store.receive(\.errorOccurred) // TODO: Check error is serverMissing

        await store.receive(\.updateUserLocation)
        await store.receive(\.connection.clearErrors)
        await clock.advance(by: .seconds(1))
        await store.receive(\.connection.localAgent.event.state.disconnected) {
            $0.connection.localAgent = .disconnected(nil)
        }
        await store.send(.connection(.localAgent(.stopObservingEvents)))
    }

    @MainActor
    func testUserClickedConnect() async {
        let clock = TestClock()
        let mockVPNSession = VPNSessionMock(status: .disconnected)
        let store = TestStore(initialState: MainFeature.State(homeLoading: .loaded(.init()))) {
            MainFeature()
        } withDependencies: {
            $0.serverIdentifier = .init(fullServerInfo: { _ in nil })
            $0.serverRepository = .notEmpty()
            $0.continuousClock = clock
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
        }
        @Shared(.connectionState) var connectionState: ConnectionState?

        store.exhaustivity = .off

        connectionState = .disconnected(nil)
        await store.send(.homeLoading(.loaded(.protectionStatus(.delegate(.userClickedConnect)))))

        await store.receive(\.connection.connect) {
            $0.connection.tunnel = .disconnected(nil)
        }
        await store.receive(\.connection.tunnel.connect) {
            $0.connection.tunnel = .connecting(.init(logicalID: "", serverID: "some id"))
        }
    }
}
