//
//  Created on 07/06/2024.
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
import SnapshotTesting
import ComposableArchitecture
@testable import tvOS
import SwiftUI
@testable import Connection
import Domain
import struct Ergonomics.GenericError
@testable import ExtensionManager
@testable import LocalAgent
import PersistenceTestSupport
import DomainTestSupport

final class MainFeatureSnapshotTests: XCTestCase {

    func testLightMainLoading() {
        mainLoading(trait: .light)
    }

    func testDarkMainLoading() {
        mainLoading(trait: .dark)
    }

    func testLightMainLoaded() {
        mainLoaded(trait: .light)
    }

    func testDarkMainLoaded() {
        mainLoaded(trait: .dark)
    }

    func mainLoading(trait: UIUserInterfaceStyle) {
        let store = Store(initialState: MainFeature.State(homeLoading: .loading)) {
            MainFeature()
        } withDependencies: {
            $0.userLocationService = UserLocationServiceMock()
            $0.serverRepository = .empty()
            $0.logicalsRefresher = .init(refreshLogicals: { throw "" as GenericError },
                                         shouldRefreshLogicals: { true })
            $0.tunnelManager = MockTunnelManager()
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.continuousClock = TestClock()
        }

        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        assertSnapshot(of: mainView, as: .image(traits: trait.collection), testName: "1 Loading " + trait.name)
    }

    func mainLoaded(trait: UIUserInterfaceStyle) {
        let store = Store(initialState: MainFeature.State(homeLoading: .loaded(.init()))) {
            MainFeature()
        } withDependencies: {
            $0.userLocationService = UserLocationServiceMock()
            $0.serverRepository = .somePlusRecommendedCountries()
            $0.tunnelManager = MockTunnelManager()
            $0.localAgent = LocalAgentMock(state: .disconnected)
        }

        @Shared(.userLocation) var userLocation: UserLocation?
        $userLocation.withLock { $0 = .init(ip: "1.2.3.4", country: "PL", isp: "") }

        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))
        
        store.send(.connection(.input(.onLaunch)))

        @Shared(.connectionState) var connectionState: ConnectionState
        
        $connectionState.withLock { $0 = .disconnected }
        assertSnapshot(of: mainView, as: .image(traits: trait.collection), testName: "1 Disconnected " + trait.name)

        let connectionPreparationIntent = ConnectionPreparationIntent(spec: .defaultFastest, server: .ca)
        $connectionState.withLock { $0 = .connecting(connectionPreparationIntent, .ca) }
        assertSnapshot(of: mainView, as: .image(traits: trait.collection), testName: "2 Connecting " + trait.name)

        let connectionIntent = ServerConnectionIntent(spec: .defaultFastest, server: .ca, tunnelSettings: .mock, features: .defaultFeatures)
        $connectionState.withLock { $0 = .connected(connectionIntent, .ca, .now, nil) }
        assertSnapshot(of: mainView, as: .image(traits: trait.collection), testName: "3 Connected " + trait.name)
    }
}
