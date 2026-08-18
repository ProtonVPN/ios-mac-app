//
//  Created on 19/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
@testable import CountriesShared
import Domain
import Foundation
import Persistence
import PersistenceTestSupport
import Testing
import VPNAppCore

/// A single United Kingdom section, the shape `SearchRoot` reads to build its index.
private func britishSection(isUnderMaintenance: Bool) -> CountrySectionFeature.State {
    let group = ServerGroupInfo.stub(kind: .country(code: "GB"), isUnderMaintenance: isUnderMaintenance)
    return CountrySectionFeature.State(
        id: .allCountries,
        type: .countries,
        title: nil,
        rows: [.country(.init(
            serverGroup: group,
            serverType: .standard,
            showCountryConnectButton: true,
            showFeatureIcons: true,
            serversFilter: .default
        ))],
        hasInfoButton: false,
        serversFilter: .default
    )
}

private func repository(returning servers: [ServerInfo]) -> ServerRepository {
    var repository = ServerRepository.notEmpty()
    repository.servers = { _, _ in servers }
    return repository
}

@Suite("SearchRoot Tests")
@MainActor
struct SearchRootTests {
    @Test("onAppear triggers preprocessing and loads placeholder")
    func onAppearLoadsPlaceholderWhenNoRecents() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.recentSearches) var recentSearches
            $recentSearches.withLock { $0 = [] }

            let store = TestStore(initialState: SearchRoot.State.loading([], query: "")) {
                SearchRoot()
            }

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded) {
                $0 = .loaded(.init(searchResults: .placeholder))
            }
        }
    }

    @Test("onAppear initializes recent searches state when storage has data")
    func onAppearLoadsRecentSearchesState() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.recentSearches) var recentSearches
            $recentSearches.withLock { $0 = ["uk"] }

            let store = TestStore(initialState: SearchRoot.State.loading([], query: "")) {
                SearchRoot()
            }

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded) {
                $0 = .loaded(.init(searchResults: .recentSearches(.init())))
            }
        }
    }

    @Test("performComputation is ignored when already loaded")
    func performComputationIgnoredWhenLoaded() async {
        let store = TestStore(initialState: SearchRoot.State.loaded(.init(searchResults: .placeholder))) {
            SearchRoot()
        }

        await store.send(.performComputation)
    }

    @Test("a place reports maintenance only when every server in it is down")
    func maintenanceFollowsEveryServerInThePlace() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        // London keeps one working server. Every server in Manchester is down, and so is the whole
        // Northwest state that holds it. The last server names a state but no city.
        let servers = [
            ServerInfo.stub(logical: .stub(id: "UK#1", exitCountryCode: "GB", city: "London", state: "England")),
            ServerInfo.stub(logical: .stub(
                id: "UK#2",
                exitCountryCode: "GB",
                city: "London",
                state: "England",
                isUnderMaintenance: true
            )),
            ServerInfo.stub(logical: .stub(
                id: "UK#3",
                exitCountryCode: "GB",
                city: "Manchester",
                state: "Northwest",
                isUnderMaintenance: true
            )),
            ServerInfo.stub(logical: .stub(id: "UK#4", exitCountryCode: "GB", state: "Southeast")),
        ]

        try await withDependencies {
            $0.defaultAppStorage = defaults
            $0.serverRepository = repository(returning: servers)
        } operation: {
            @Shared(.userTier) var userTier: VpnTier?
            $userTier.withLock { $0 = .paid }

            let store = TestStore(initialState: SearchRoot.State.loading([britishSection(isUnderMaintenance: false)], query: "")) {
                SearchRoot()
            }
            store.exhaustivity = .off

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded)

            let searchState = try #require(store.state.loaded)
            #expect(searchState.allCountries.map(\.underMaintenance) == [false])

            let cities = Dictionary(uniqueKeysWithValues: searchState.allCities.map { ($0.cityName, $0.underMaintenance) })
            #expect(cities["London"] == false)
            #expect(cities["Manchester"] == true)

            let states = Dictionary(uniqueKeysWithValues: searchState.allStates.map { ($0.cityName, $0.underMaintenance) })
            #expect(states["England"] == false)
            #expect(states["Northwest"] == true)
            // A server that names its state but not its city still reaches its state row.
            #expect(states["Southeast"] == false)

            // A state row shows the state's own name, never a city borrowed from one of its servers.
            #expect(searchState.allStates.allSatisfy { $0.translatedCityName == nil })
        }
    }

    @Test("a country with nothing to connect to carries maintenance into its search row")
    func countryMaintenanceReachesTheSearchRow() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        try await withDependencies {
            $0.defaultAppStorage = defaults
            $0.serverRepository = repository(returning: [])
        } operation: {
            let store = TestStore(initialState: SearchRoot.State.loading([britishSection(isUnderMaintenance: true)], query: "")) {
                SearchRoot()
            }
            store.exhaustivity = .off

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded)

            let searchState = try #require(store.state.loaded)
            #expect(searchState.allCountries.map(\.underMaintenance) == [true])
        }
    }

    @Test("search delegate bubbles to root delegate")
    func searchDelegateBubblesToRoot() async {
        let store = TestStore(initialState: .loaded(.init(searchResults: .placeholder))) {
            SearchRoot()
        }
        store.exhaustivity = .off

        await store.send(.loaded(.delegate(.showUpsell)))
    }
}
