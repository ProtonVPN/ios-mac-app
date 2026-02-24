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
import Connection
import Domain
import DomainTestSupport
import PersistenceTestSupport
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics
@testable import tvos_app

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
final class MainFeatureSnapshotTests {
    @Test("Main loading - Light")
    func lightMainLoading() {
        mainLoading(trait: .light)
    }

    @Test("Main loading - Dark")
    func darkMainLoading() {
        mainLoading(trait: .dark)
    }

    @Test("Main loaded - Light")
    func lightMainLoaded() {
        mainLoaded(trait: .light)
    }

    @Test("Main loaded - Dark")
    func darkMainLoaded() {
        mainLoaded(trait: .dark)
    }

    func mainLoading(trait: UIUserInterfaceStyle) {
        let store = makeStore(state: MainFeature.State(homeLoading: .loading))
        let mainView = MainView(store: store)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        snap(mainView, caseName: "1 Loading", trait: trait)
    }

    func mainLoaded(trait: UIUserInterfaceStyle) {
        @Shared(.userLocation) var userLocation: UserLocation?
        $userLocation.withLock { $0 = .init(ip: "1.2.3.4", country: "CA", isp: "") }

        let loadedHomeState = makeLoadedHomeState()
        let disconnectedStore = makeStore(
            state: MainFeature.State(homeLoading: loadedHomeState),
            mainBackground: .disconnected,
            connectionState: .disconnected
        )
        let disconnectedView = MainView(store: disconnectedStore)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))
        snap(disconnectedView, caseName: "1 Disconnected", trait: trait)

        let connectingStore = makeStore(
            state: MainFeature.State(homeLoading: loadedHomeState),
            mainBackground: .connecting,
            connectionState: .connecting(
                .unresolved(
                    .init(
                        spec: .init(location: .country(code: "CA", order: .fastest), features: []),
                        acceptableProtocols: .all
                    )
                )
            )
        )
        let connectingView = MainView(store: connectingStore)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))
        snap(connectingView, caseName: "2 Connecting", trait: trait)

        let connectedStore = makeStore(
            state: MainFeature.State(homeLoading: loadedHomeState),
            mainBackground: .connected,
            connectionState: .connected(
                .init(
                    spec: .init(location: .country(code: "CA", order: .fastest), features: []),
                    server: .ca,
                    tunnelSettings: .mock,
                    features: .defaultFeatures
                ),
                .ca,
                .now,
                nil
            )
        )
        let connectedView = MainView(store: connectedStore)
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))
        snap(connectedView, caseName: "3 Connected", trait: trait)
    }
}

private extension MainFeatureSnapshotTests {
    func makeStore(
        state: MainFeature.State,
        mainBackground: MainBackground = .clear,
        connectionState: ConnectionState = .resolving
    ) -> StoreOf<MainFeature> {
        @Shared(.mainBackground) var sharedBackground: MainBackground
        $sharedBackground.withLock { $0 = mainBackground }
        @Shared(.connectionState) var sharedConnectionState: ConnectionState
        $sharedConnectionState.withLock { $0 = connectionState }

        return Store(initialState: state) {
            EmptyReducer()
        }
    }

    func makeLoadedHomeState() -> HomeLoadingFeature.State {
        withDependencies {
            // when we move serverRepository dependency out of CountryListFeature init
            // this will not be needed
            $0.serverRepository = .somePlusRecommendedCountries()
        } operation: {
            .loaded(.init())
        }
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
