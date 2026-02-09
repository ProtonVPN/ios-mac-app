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

import ComposableArchitecture
@testable import Connection
import Domain
import DomainTestSupport
import struct Ergonomics.GenericError
@testable import ExtensionManager
@testable import LocalAgent
import PersistenceTestSupport
import SnapshotTesting
import SwiftUI
import System
import TestingErgonomics
@testable import tvos_app
import XCTest

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
            $0.logicalsRefresher = .init(
                refreshLogicals: { throw "" as GenericError },
                shouldRefreshLogicals: { true }
            )
            $0.tunnelManager = MockTunnelManager()
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.continuousClock = TestClock()
        }

        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        snap(mainView, caseName: "1 Loading", trait: trait)
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
        $userLocation.withLock { $0 = .init(ip: "1.2.3.4", country: "CA", isp: "") }

        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        store.send(.connection(.input(.onLaunch)))
        store.send(.observeConnectionState)

        @Shared(.connectionState) var connectionState: ConnectionState

        $connectionState.withLock { $0 = .disconnected }
        snap(mainView, caseName: "1 Disconnected", trait: trait)

        let connectionPreparationIntent = ConnectionPreparationIntent(
            spec: .init(location: .country(code: "CA", order: .fastest), features: []),
            acceptableProtocols: .all
        )
        $connectionState.withLock { $0 = .connecting(.unresolved(connectionPreparationIntent)) }
        snap(mainView, caseName: "2 Connecting", trait: trait)

        let connectionIntent = ServerConnectionIntent(spec: .defaultFastest, server: .ca, tunnelSettings: .mock, features: .defaultFeatures)
        $connectionState.withLock { $0 = .connected(connectionIntent, .ca, .now, nil) }
        snap(mainView, caseName: "3 Connected", trait: trait)
    }
}

extension MainFeatureSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
            return nil
        }

        let path = FilePath(String(describing: #filePath))
        let suite = path.lastComponent?.stem ?? ""
        return "\(projectDir)/libraries/Features/tvos_app/Tests/tvos_appSnapshotTests/__Snapshots__/\(suite)"
    }
}
