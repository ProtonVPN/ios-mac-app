//
//  Created on 28/01/2026 by Max Kupetskyi.
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

import CommonNetworking
import ComposableArchitecture
import Dependencies
import Domain
import Localization
import Persistence

@Reducer
public struct SearchRoot {
    @ObservableState
    public enum State: Equatable {
        case loading(IdentifiedArrayOf<CountrySectionFeature.State>)
        case loaded(SearchFeature.State)
    }

    public enum Action {
        case onAppear
        case performComputation
        case dataLoaded(SearchFeature.State)
        case loaded(SearchFeature.Action)
    }

    @Dependency(\.searchStorageNew) private var searchStorage

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.performComputation)

            case .performComputation:
                guard let sections = state.sections else { return .none }
                return .run { [sections, searchStorage] send in
                    // Run expensive preprocessing work off the reducer path
                    let countryStates = try sections.flatMap { section -> [CountryFeature.State] in
                        try Task.checkCancellation()
                        return section.rows.compactMap { row -> CountryFeature.State? in
                            guard case let .country(countryState) = row else { return nil }
                            return countryState
                        }
                    }

                    let countries = countryStates.map { country in
                        SearchCountryIndex(
                            id: country.id,
                            countryCode: country.countryCode,
                            name: country.description
                        )
                    }

                    let (cities, freeServers, plusServers) = try Self.computeSearchableData(from: countryStates)
                    try Task.checkCancellation()

                    let recentSearches = searchStorage.get()
                    let searchResultsViewState = if recentSearches.isEmpty {
                        SearchResultsFeature.State.placeholder
                    } else {
                        SearchResultsFeature.State.recentSearches(.init())
                    }

                    await send(.dataLoaded(.init(
                        allCountries: countries,
                        allCities: cities,
                        freeServers: freeServers,
                        plusServers: plusServers,
                        searchResults: searchResultsViewState
                    )))
                }

            case let .dataLoaded(searchState):
                state = .loaded(searchState)
                return .none

            case .loaded:
                return .none
            }
        }
        .ifCaseLet(\.loaded, action: \.loaded) {
            SearchFeature()
        }
    }

    /// Computes all searchable data once from countries
    /// Returns: (cities, freeServers, plusServers)
    private static func computeSearchableData(
        from countries: [CountryFeature.State]
    ) throws -> (cities: [SearchCityIndex], freeServers: [SearchServerIndex], plusServers: [SearchServerIndex]) {
        @Dependency(\.serverRepository) var serverRepository
        @Dependency(\.propertiesManager) var propertiesManager
        @SharedReader(.secureCoreToggle) var isSecureCore: Bool
        @SharedReader(.userTier) var userTier: Int?

        var citiesByID: [String: SearchCityAccumulator] = [:]
        var freeServers: [SearchServerIndex] = []
        var plusServers: [SearchServerIndex] = []

        for country in countries {
            try Task.checkCancellation()

            // Get servers for this country
            let kindFilter = country.serverGroup.kind.filter
            let protocolFilter = VPNServerFilter.supports(protocol: propertiesManager.currentProtocolSupport)
            let featureFilter = VPNServerFilter.features(isSecureCore ? .secureCore : .standard)
            let filters = [kindFilter, featureFilter, protocolFilter]

            let servers = serverRepository.getServers(filteredBy: filters, orderedBy: .loadAscending)

            for serverInfo in servers {
                let server = buildServerIndex(
                    serverInfo: serverInfo,
                    serverType: country.serverType,
                    userTier: userTier ?? Int.freeTier,
                    underMaintenance: serverInfo.logical.isUnderMaintenance
                        || serverInfo.protocolSupport.isDisjoint(with: propertiesManager.currentProtocolSupport)
                )

                if server.tier == .free {
                    freeServers.append(server)
                } else {
                    plusServers.append(server)
                }

                try Task.checkCancellation()
                guard let cityName = serverInfo.logical.city, !cityName.isEmpty else { continue }
                let cityID = "\(cityName)-\(country.countryCode)"

                if var city = citiesByID[cityID] {
                    city.add(server: server)
                    citiesByID[cityID] = city
                } else {
                    citiesByID[cityID] = SearchCityAccumulator(
                        cityName: cityName,
                        translatedCityName: server.translatedCityName,
                        countryName: server.countryName,
                        countryCode: country.countryCode
                    )
                }
            }
        }

        let sortedCities = citiesByID.values
            .map(\.asIndex)
            .sorted { $0.cityName < $1.cityName }
        return (sortedCities, freeServers, plusServers)
    }

    private static func buildServerIndex(
        serverInfo: ServerInfo,
        serverType: ServerType,
        userTier: Int,
        underMaintenance: Bool
    ) -> SearchServerIndex {
        let logical = serverInfo.logical

        return SearchServerIndex(
            id: logical.id,
            serverName: logical.name,
            cityName: logical.city ?? "",
            translatedCityName: logical.translatedCity,
            countryName: LocalizationUtility.default.countryName(forCode: logical.exitCountryCode) ?? "",
            exitCountryCode: logical.exitCountryCode,
            entryCountryCode: serverType == .secureCore ? logical.entryCountryCode : nil,
            tier: logical.tier.isFreeTier ? .free : .plus,
            load: logical.load,
            isP2PAvailable: logical.feature.contains(.p2p),
            isTorAvailable: logical.feature.contains(.tor),
            isSmartAvailable: logical.isVirtual,
            isStreamingAvailable: serverType != .secureCore && logical.feature.contains(.streaming),
            isUsersTierTooLow: userTier < logical.tier,
            underMaintenance: underMaintenance
        )
    }
}

private struct SearchCityAccumulator {
    let cityName: String
    var translatedCityName: String?
    let countryName: String
    let countryCode: String

    init(cityName: String, translatedCityName: String?, countryName: String, countryCode: String) {
        self.cityName = cityName
        self.translatedCityName = translatedCityName
        self.countryName = countryName
        self.countryCode = countryCode
    }

    mutating func add(server: SearchServerIndex) {
        if translatedCityName == nil {
            translatedCityName = server.translatedCityName
        }
    }

    var asIndex: SearchCityIndex {
        SearchCityIndex(
            id: "\(cityName)-\(countryCode)",
            cityName: cityName,
            translatedCityName: translatedCityName,
            countryName: countryName,
            countryCode: countryCode
        )
    }
}

extension SearchRoot.State {
    var sections: IdentifiedArrayOf<CountrySectionFeature.State>? {
        switch self {
        case let .loading(searchData):
            searchData
        case .loaded:
            nil
        }
    }
}
