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
@testable import ExtensionManager
@testable import LocalAgentTestSupport
@testable import LocalAgent

final class MainFeatureSnapshotTests: XCTestCase {

    @MainActor
    func testMain() async {
        let store = Store(initialState: MainFeature.State(homeLoading: .loading)) {
            MainFeature()
        } withDependencies: {
            $0.userLocationService = UserLocationServiceMock()
            $0.serverRepository = .somePlusRecommendedCountries()
            $0.logicalsRefresher = .init(refreshLogicals: { },
                                         shouldRefreshLogicals: { false })
            $0.tunnelManager = MockTunnelManager()
            $0.localAgent = LocalAgentMock(state: .disconnected)
        }

        @Shared(.userLocation) var userLocation: UserLocation?
        userLocation = .init(ip: "1.2.3.4", country: "PL", isp: "")

        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        assertSnapshot(of: mainView, as: .image(traits: .darkMode), named: "1 Loading")
        store.send(.homeLoading(.finishedLoading(.success(Void()))))

        @Shared(.connectionState) var connectionState: ConnectionState?

        connectionState = .disconnected(nil)
        assertSnapshot(of: mainView, as: .image(traits: .darkMode), named: "2 Disconnected")
        connectionState = .connecting
        assertSnapshot(of: mainView, as: .image(traits: .darkMode), named: "3 Connecting")
        connectionState = .connected(.ca)
        assertSnapshot(of: mainView, as: .image(traits: .darkMode), named: "4 Connected")
    }
}
