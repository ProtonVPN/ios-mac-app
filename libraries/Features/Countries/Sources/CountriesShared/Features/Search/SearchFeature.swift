//
//  Created on 27/01/2026 by Max Kupetskyi.
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
import Dependencies
import Foundation
import Strings

@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        // Pre-computed searchable data (computed once on initialization, reused for filtering)
        var allCountries: [SearchCountryIndex] = []
        var allCities: [SearchCityIndex] = []
        var freeServers: [SearchServerIndex] = []
        var plusServers: [SearchServerIndex] = []

        // Search state
        public var searchQuery: String = ""

        // Display state - determines what to show
        public var searchResults: SearchResultsFeature.State

        // Computed from parent via shared state
        @SharedReader(.userTier) var userTier: Int?
        @SharedReader(.secureCoreToggle) var isSecureCore: Bool

        // Computed mode based on shared state
        public var mode: SearchMode {
            if isSecureCore {
                return .secureCore
            }

            let isFreeTier = userTier?.isFreeTier ?? true
            return .standard(isFreeTier: isFreeTier)
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case searchResults(SearchResultsFeature.Action)

        // Search actions
        case searchQueryChanged(String)
        case searchQueryChangeDebounced
        case performSearch(String)
    }

    @Dependency(\.searchStorageNew) private var searchStorage

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.searchResults, action: \.searchResults) {
            SearchResultsFeature()
        }

        Reduce { state, action in
            switch action {
            case let .searchQueryChanged(query):
                state.searchQuery = query
                return .none

            case .searchQueryChangeDebounced:
                return .send(.performSearch(state.searchQuery))

            case let .performSearch(searchText):
                let trimmedText = searchText.trimmingCharacters(in: .whitespaces)

                // Empty search - show recent searches or placeholder
                guard !trimmedText.isEmpty else {
                    let recentSearches = searchStorage.get()
                    state.searchResults = recentSearches.isEmpty ? .placeholder :
                        .recentSearches(.init(recentSearches: recentSearches))
                    return .none
                }

                // save query
                saveQuery(trimmedText)

                // Perform actual search
                let rows = performSearchLogic(
                    searchText: trimmedText,
                    state: state
                )

                state.searchResults = rows.isEmpty
                    ? .noResults
                    : .resultsDisplay(.init(rows: rows, searchText: trimmedText))
                return .none

            case let .searchResults(.recentSearches(.recentTapped(searchText))):
                // User tapped a recent search - trigger search with that text
                state.searchQuery = searchText
                return .send(.performSearch(searchText))

            case .searchResults(.recentSearches(.recentsCleared)):
                state.searchResults = .placeholder
                return .none

            case .binding:
                return .none

            case .searchResults:
                return .none
            }
        }
    }

    // MARK: - Search Logic

    private func performSearchLogic(
        searchText: String,
        state: State
    ) -> IdentifiedArrayOf<SearchResultRow> {
        let filter = makeFilter(for: searchText)

        var rows: [SearchResultRow] = []

        switch state.mode {
        case let .standard(isFreeTier):
            var hasResults = false

            // Filter countries
            let countries = state.allCountries.filter { filter($0.name) }
            if !countries.isEmpty {
                hasResults = true
                let header = "\(Localizable.searchResultsCountries) (\(countries.count))"
                rows.append(.sectionHeader(header))
                rows.append(contentsOf: countries.map { .country($0) })
            }

            // Filter cities from pre-computed list
            let cities = state.allCities.filter { city in
                filter(city.cityName)
                    || filter(city.translatedCityName ?? "")
                    || filter(city.countryName)
            }
            if !cities.isEmpty {
                hasResults = true
                let header = "\(Localizable.searchCities) (\(cities.count))"
                rows.append(.sectionHeader(header))
                rows.append(contentsOf: cities.map { .city($0) })
            }

            // Filter servers by tier from pre-computed lists
            for serverTier in ServerTier.sorted(isFreeTier: isFreeTier) {
                let tierServers: [SearchServerIndex] = switch serverTier {
                case .free:
                    state.freeServers.filter { filter($0.serverName) }
                case .plus:
                    state.plusServers.filter { filter($0.serverName) }
                }

                if !tierServers.isEmpty {
                    hasResults = true
                    let header = "\(serverTier.title) (\(tierServers.count))"
                    rows.append(.sectionHeader(header))
                    rows.append(contentsOf: tierServers.map { .server($0) })
                }
            }

            // Add upsell at the beginning if there are results
            if isFreeTier, hasResults {
                rows.insert(.upsell, at: 0)
            }

        case .secureCore:
            // For secure core, filter matching countries and their servers
            let countries = state.allCountries.filter { filter($0.name) }
            // In secure core, we show all servers from matching countries
            let allServers = state.freeServers + state.plusServers
            let servers = allServers.filter { server in
                countries.contains { country in
                    country.countryCode == server.exitCountryCode
                }
            }

            if !servers.isEmpty {
                let header = "\(Localizable.searchSecureCoreCountries) (\(servers.count))"
                rows.append(.sectionHeader(header))
                rows.append(contentsOf: servers.map { .secureCoreCountry($0) })
            }
        }

        return IdentifiedArray(uniqueElements: rows)
    }

    // MARK: - Helper Methods

    private func makeFilter(for searchText: String) -> (String) -> Bool {
        let normalizedSearchText = searchText.normalized

        return { name in
            let normalizedName = name.normalized

            // Full match
            if normalizedName.starts(with: normalizedSearchText) {
                return true
            }

            // Any word in the name matches the search text
            let normalizedParts = name
                .components(separatedBy: .whitespaces)
                .map(\.normalized)

            return normalizedParts.contains { $0.starts(with: normalizedSearchText) }
        }
    }

    // Saving recents, we should rework searchStorage

    private func saveQuery(_ searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        var recentSearches = searchStorage.get()
        // Remove if exists and add to front
        recentSearches.removeAll { $0 == trimmedText }

        // Limit to 5 recent searches
        if recentSearches.count >= 5 {
            recentSearches = Array(recentSearches.dropLast())
        }

        recentSearches.insert(trimmedText, at: 0)
        searchStorage.save(data: recentSearches)
    }
}

// MARK: - String Extensions

extension String {
    var normalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
