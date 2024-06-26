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
@testable import LocalAgentTestSupport
@testable import LocalAgent

final class MainFeatureTests: XCTestCase {

    @MainActor
    func testTabSelection() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.selectTab(.settings)) {
            $0.currentTab = .settings
        }
        await store.send(.selectTab(.home)) {
            $0.currentTab = .home
        }
    }

    @MainActor
    func testSettingsContactUs() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.settings(.showDrillDown(.contactUs))) {
            $0.settings.destination = .settingsDrillDown(.contactUs)
        }
    }

    @MainActor
    func testErrorConnectingShowsAlert() async {
        let store = TestStore(initialState: MainFeature.State(homeLoading: .loaded(.init()))) {
            MainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }
        let error = ConnectionError.serverMissing
        await store.send(.connectionFailed(.serverMissing)) {
            $0.alert = MainFeature.connectionFailedAlert(reason: error.description)
        }
    }


    @MainActor
    func testUserClickedConnect() async {
        let clock = TestClock()
        let mockVPNSession = VPNSessionMock(status: .disconnected)
        let store = TestStore(initialState: MainFeature.State(homeLoading: .loaded(.init()))) {
            MainFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
            $0.continuousClock = clock
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
        }
        @Shared(.connectionState) var connectionState: ConnectionState?

        store.exhaustivity = .off

        connectionState = .disconnected(nil)
        await store.send(.homeLoading(.loaded(.protectionStatus(.userClickedConnect))))

        await store.receive(\.connection.connect)
        await store.receive(\.connection.tunnel.connect) {
            $0.connection.tunnel = .connecting
            $0.connectionState = .connecting
        }
    }
}
