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
import Strings
import Testing

@Suite("SearchFeature Tests")
@MainActor
struct SearchFeatureReducerTests {
    @Test("searchQueryChangeDebounced sends performSearch with current query")
    func searchQueryDebounceFlow() async {
        let store = TestStore(initialState: SearchFeature.State(searchResults: .placeholder)) {
            SearchFeature()
        } withDependencies: {
            $0.searchStorageNew.save = { _ in }
        }

        await store.send(.searchQueryChanged("Test")) {
            $0.searchQuery = "Test"
        }
        await store.send(.searchQueryChangeDebounced)
        await store.receive(\.performSearch) {
            $0.searchResults = .noResults
        }
    }

    @Test("empty search loads recents from storage")
    func emptySearchLoadsRecents() async {
        let store = TestStore(initialState: SearchFeature.State(searchResults: .placeholder)) {
            SearchFeature()
        } withDependencies: {
            $0.searchStorageNew.get = { ["Dd", "Uk"] }
        }

        await store.send(.performSearch("   ")) {
            $0.searchResults = .recentSearches(.init(recentSearches: ["Dd", "Uk"]))
        }
    }

    @Test("standard search returns results with upsell for free user")
    func standardSearchBuildsResultsWithUpsell() async {
        @Shared(.secureCoreToggle) var secureCoreToggle = false
        @Shared(.userTier) var userTier: Int? = 0

        let savedQueries = LockIsolated<[[String]]>([])
        let initialState = SearchFeature.State(
            allCountries: [
                SearchCountryIndex(id: "GB", countryCode: "GB", name: "United Kingdom"),
            ],
            allCities: [],
            freeServers: [
                SearchServerIndex(
                    id: "gb-1",
                    serverName: "UK#1",
                    cityName: "London",
                    translatedCityName: nil,
                    countryName: "United Kingdom",
                    exitCountryCode: "GB",
                    entryCountryCode: nil,
                    tier: .free,
                    load: 42,
                    isP2PAvailable: false,
                    isTorAvailable: false,
                    isSmartAvailable: false,
                    isStreamingAvailable: false,
                    isUsersTierTooLow: false,
                    underMaintenance: false
                ),
            ],
            plusServers: [],
            searchResults: .placeholder
        )

        let store = TestStore(initialState: initialState) {
            SearchFeature()
        } withDependencies: {
            $0.searchStorageNew.save = { newQ in savedQueries.withValue { $0.append(newQ) } }
        }

        await store.send(.performSearch("uk")) {
            let server = $0.freeServers[0]
            $0.searchResults = .resultsDisplay(
                .init(
                    rows: [
                        .upsell,
                        .sectionHeader("\(ServerTier.free.title) (1)"),
                        .server(server),
                    ],
                    searchText: "uk"
                )
            )
        }
    }

    @Test("secure core mode returns secure core rows")
    func secureCoreSearchBuildsSecureCoreRows() async {
        @Shared(.secureCoreToggle) var secureCoreToggle = true
        @Shared(.userTier) var userTier: Int? = 2

        let initialState = SearchFeature.State(
            allCountries: [
                SearchCountryIndex(id: "CH", countryCode: "CH", name: "Switzerland"),
            ],
            allCities: [],
            freeServers: [
                SearchServerIndex(
                    id: "ch-1",
                    serverName: "CH#1",
                    cityName: "Zurich",
                    translatedCityName: nil,
                    countryName: "Switzerland",
                    exitCountryCode: "CH",
                    entryCountryCode: "SE",
                    tier: .free,
                    load: 12,
                    isP2PAvailable: false,
                    isTorAvailable: false,
                    isSmartAvailable: false,
                    isStreamingAvailable: false,
                    isUsersTierTooLow: false,
                    underMaintenance: false
                ),
            ],
            plusServers: [],
            searchResults: .placeholder
        )

        let store = TestStore(initialState: initialState) {
            SearchFeature()
        } withDependencies: {
            $0.searchStorageNew.save = { _ in }
        }

        await store.send(.performSearch("sw")) {
            let server = $0.freeServers[0]
            $0.searchResults = .resultsDisplay(
                .init(
                    rows: [
                        .sectionHeader("\(Localizable.searchSecureCoreCountries) (1)"),
                        .secureCoreCountry(server),
                    ],
                    searchText: "sw"
                )
            )
        }
    }

    @Test("tapping recent search updates query and performs search")
    func recentTappedTriggersSearch() async {
        let state = SearchFeature.State(
            allCountries: [],
            allCities: [],
            freeServers: [],
            plusServers: [],
            searchResults: .recentSearches(.init(recentSearches: ["Te"]))
        )
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchStorageNew.save = { _ in }
        }

        await store.send(.searchResults(.recentSearches(.recentTapped("Te")))) {
            $0.searchQuery = "Te"
        }
        await store.receive(\.performSearch) {
            $0.searchResults = .noResults
        }
    }

    @Test("recents cleared resets to placeholder")
    func recentsClearedResetsPlaceholder() async {
        let store = TestStore(
            initialState: SearchFeature.State(searchResults: .recentSearches(.init(recentSearches: ["A"])))
        ) {
            SearchFeature()
        }

        await store.send(.searchResults(.recentSearches(.recentsCleared))) {
            $0.searchResults = .placeholder
        }
    }
}
