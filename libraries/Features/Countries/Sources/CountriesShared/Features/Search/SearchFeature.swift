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
import Domain
import Foundation

// MARK: - Supporting Types

public enum SearchMode: Equatable {
    case standard(isFreeTier: Bool)
    case secureCore
}

public enum ServerTier: Int, Equatable {
    case free = 0
    case plus = 2

    public static func sorted(isFreeTier: Bool) -> [ServerTier] {
        isFreeTier ? [.free, .plus] : [.plus, .free]
    }
}

// MARK: - SearchFeature Reducer

@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        // Data source - all available countries from parent feature
        var searchData: IdentifiedArrayOf<CountryFeature.State> = []

        // Search state
        var searchQuery: String = ""

        // Display state - determines what to show
        var searchResults: SearchResultsFeature.State = .placeholder

        // Configuration
        var numberOfCountries: Int = 0 // TODO: get from serversRepository

        // Computed from parent via shared state
        @SharedReader(.userTier) var userTier: Int?
        @SharedReader(.secureCoreToggle) var isSecureCore: Bool

        // Computed mode based on shared state
        var mode: SearchMode {
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

        // Lifecycle
        case dismiss
    }

    @Dependency(\.searchStorageNew) private var searchStorage
    @Dependency(\.continuousClock) private var clock

    private enum CancelID { case searchDebounce }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.searchResults, action: \.searchResults) {
            SearchResultsFeature()
        }

        Reduce { state, action in
            switch action {
                // Search

            case let .searchQueryChanged(query):
                state.searchQuery = query

                // Cancel previous debounce and start new one
                return .concatenate(
                    .cancel(id: CancelID.searchDebounce),
                    .run { [clock] send in
                        try await clock.sleep(for: .milliseconds(300)) // TODO: Move to the corresponding view
                        await send(.searchQueryChangeDebounced)
                    }
                    .cancellable(id: CancelID.searchDebounce)
                )

            case .searchQueryChangeDebounced:
                return .send(.performSearch(state.searchQuery))

            case let .performSearch(searchText):
                let trimmedText = searchText.trimmingCharacters(in: .whitespaces)

                // save query
                saveQuery(trimmedText)

                // Empty search - show recent searches or placeholder
                guard !trimmedText.isEmpty else {
                    let recentSearches = searchStorage.get()
                    state.searchResults = recentSearches.isEmpty ? .placeholder : .recentSearches(.init())
                    return .none
                }

                // Perform actual search
                let results = performSearchLogic(
                    searchText: trimmedText,
                    data: state.searchData,
                    mode: state.mode
                )

                state.searchResults = results.isEmpty
                    ? .noResults
                    : .resultsDisplay(.init(searchResults: results))
                return .none

            case let .searchResults(.recentSearches(.recentTapped(searchText))):
                // User tapped a recent search - trigger search with that text
                state.searchQuery = searchText
                return .send(.performSearch(searchText))

            case .dismiss:
                // Save current search if any
                guard !state.searchQuery.isEmpty else { return .none }
                saveQuery(state.searchQuery)
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
        data: IdentifiedArrayOf<CountryFeature.State>,
        mode: SearchMode
    ) -> [SearchResult] {
        let filter = makeFilter(for: searchText)

        var results: [SearchResult] = []

        switch mode {
        case let .standard(isFreeTier):
            // Filter countries
            let countries = data.filter { filter($0.description) }
            if !countries.isEmpty {
                results.append(.countries(Array(countries)))
            }

            // Filter cities
            let allCities = data.flatMap { country in
                country.cities.filter { city in
                    filter(city.cityName)
                        || filter(city.translatedCityName ?? "")
                        || filter(country.countryName)
                }
            }
            let sortedCities = allCities.sorted { $0.cityName < $1.cityName }
            if !sortedCities.isEmpty {
                results.append(.cities(sortedCities))
            }

            // Filter servers by tier
            for serverTier in ServerTier.sorted(isFreeTier: isFreeTier) {
                let tierServers = data.flatMap { country in
                    country.serverSections
                        .filter { $0.tier.rawValue == serverTier.rawValue }
                        .flatMap(\.servers)
                        .filter { filter($0.description) }
                }

                if !tierServers.isEmpty {
                    results.append(.servers(tier: serverTier, servers: tierServers))
                }
            }

            // Add upsell for free users at the top if there are results
            if isFreeTier, !results.isEmpty {
                results.insert(.upsell, at: 0)
            }

        case .secureCore:
            // For secure core, just show matching countries with their servers
            let countries = data.filter { filter($0.description) }
            let servers = countries.flatMap { $0.serverSections.flatMap(\.servers) }

            if !servers.isEmpty {
                results.append(.secureCoreCountries(servers))
            }
        }

        return results
    }

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
