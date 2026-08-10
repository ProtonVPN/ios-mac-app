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
        /// Building the search index. `query` buffers what the user has typed so far, replayed into the
        /// loaded state the moment the index lands.
        case loading(IdentifiedArrayOf<CountrySectionFeature.State>, query: String)
        case loaded(SearchFeature.State)
    }

    public enum Action {
        case onAppear
        case performComputation
        case dataLoaded(SearchFeature.State)
        case loaded(SearchFeature.Action)
        case searchQueryChanged(String)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case showUpsell
            case showCountryUpsell(String)
            case navigateTo(ServerGroupInfo.Kind)
            case connectRequested(ConnectionSpec, UserInitiatedVPNChange.VPNTrigger?)
            case disconnectRequested(UserInitiatedVPNChange.VPNTrigger)
            case showMaintenanceAlert(SearchMaintenanceScope)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.performComputation)

            case .performComputation:
                guard let sections = state.sections else { return .none }
                return .run { [sections] send in
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
                            kind: country.serverGroup.kind,
                            name: country.description,
                            underMaintenance: country.underMaintenance
                        )
                    }

                    let (cities, states, freeServers, plusServers) = try Self.computeSearchableData(from: countryStates)
                    try Task.checkCancellation()

                    @SharedReader(.recentSearches) var storedSearches
                    let recentSearches = storedSearches ?? []
                    let searchResultsViewState = if recentSearches.isEmpty {
                        SearchResultsFeature.State.placeholder
                    } else {
                        SearchResultsFeature.State.recentSearches(.init())
                    }

                    await send(.dataLoaded(.init(
                        allCountries: countries,
                        allCities: cities,
                        allStates: states,
                        freeServers: freeServers,
                        plusServers: plusServers,
                        searchResults: searchResultsViewState
                    )))
                }

            case let .dataLoaded(searchState):
                let buffered = state.searchQuery
                state = .loaded(searchState)
                guard !buffered.isEmpty else { return .none }
                return .send(.loaded(.searchQueryChanged(buffered)))

            case let .searchQueryChanged(query):
                switch state {
                case let .loading(sections, _):
                    state = .loading(sections, query: query)
                    return .none
                case .loaded:
                    return .send(.loaded(.searchQueryChanged(query)))
                }

            case .loaded(.delegate(.showUpsell)):
                return .send(.delegate(.showUpsell))

            case let .loaded(.delegate(.showCountryUpsell(countryCode))):
                return .send(.delegate(.showCountryUpsell(countryCode)))

            case let .loaded(.delegate(.navigateTo(kind))):
                return .send(.delegate(.navigateTo(kind)))

            case let .loaded(.delegate(.connectRequested(connectionSpec, trigger))):
                return .send(.delegate(.connectRequested(connectionSpec, trigger)))

            case let .loaded(.delegate(.disconnectRequested(trigger))):
                return .send(.delegate(.disconnectRequested(trigger)))

            case let .loaded(.delegate(.showMaintenanceAlert(scope))):
                return .send(.delegate(.showMaintenanceAlert(scope)))

            case .loaded:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifCaseLet(\.loaded, action: \.loaded) {
            SearchFeature()
        }
    }

    /// Computes all searchable data once from countries
    /// Returns: (cities, states, freeServers, plusServers)
    private static func computeSearchableData(
        from countries: [CountryFeature.State]
    ) throws -> (cities: [SearchCityIndex], states: [SearchCityIndex], freeServers: [SearchServerIndex], plusServers: [SearchServerIndex]) {
        @Dependency(\.serverRepository) var serverRepository
        @SharedReader(.secureCoreToggle) var isSecureCore: Bool
        @SharedReader(.userTier) var userTier: VpnTier?

        var citiesByID: [String: SearchCityAccumulator] = [:]
        var statesByID: [String: SearchCityAccumulator] = [:]
        var freeServers: [SearchServerIndex] = []
        var plusServers: [SearchServerIndex] = []

        for country in countries {
            try Task.checkCancellation()

            // Get servers for this country
            let kindFilter = country.serverGroup.kind.filter
            let protocolFilter = VPNServerFilter.supports(protocol: currentProtocolSupport())
            let featureFilter = VPNServerFilter.features(isSecureCore ? .secureCore : .standard)
            let filters = [kindFilter, featureFilter, protocolFilter]

            let servers = serverRepository.getServers(filteredBy: filters, orderedBy: .loadAscending)

            for serverInfo in servers {
                let server = buildServerIndex(
                    serverInfo: serverInfo,
                    serverType: country.serverType,
                    userTier: userTier ?? .free,
                    underMaintenance: serverInfo.logical.isUnderMaintenance
                        || serverInfo.protocolSupport.isDisjoint(with: currentProtocolSupport())
                )

                if server.tier == .free {
                    freeServers.append(server)
                } else {
                    plusServers.append(server)
                }

                try Task.checkCancellation()

                if let cityName = serverInfo.logical.city, !cityName.isEmpty {
                    let cityID = "\(cityName)-\(country.countryCode)"
                    citiesByID[cityID, default: SearchCityAccumulator(
                        place: .city,
                        name: cityName,
                        countryName: server.countryName,
                        countryCode: country.countryCode
                    )].add(server: server)
                }

                if let stateName = serverInfo.logical.state, !stateName.isEmpty {
                    let stateID = "\(stateName)-\(country.countryCode)"
                    statesByID[stateID, default: SearchCityAccumulator(
                        place: .state,
                        name: stateName,
                        countryName: server.countryName,
                        countryCode: country.countryCode
                    )].add(server: server)
                }
            }
        }

        let sortedCities = citiesByID.values
            .map(\.asIndex)
            .sorted { $0.cityName < $1.cityName }
        let sortedStates = statesByID.values
            .map(\.asIndex)
            .sorted { $0.cityName < $1.cityName }
        return (sortedCities, sortedStates, freeServers, plusServers)
    }

    private static func buildServerIndex(
        serverInfo: ServerInfo,
        serverType: ServerType,
        userTier: VpnTier,
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
            tier: logical.tier.isFree ? .free : .plus,
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
    enum Place {
        case city
        case state
    }

    let place: Place
    let name: String
    let countryName: String
    let countryCode: String
    private(set) var translatedCityName: String?
    private(set) var underMaintenance = true

    init(place: Place, name: String, countryName: String, countryCode: String) {
        self.place = place
        self.name = name
        self.countryName = countryName
        self.countryCode = countryCode
    }

    mutating func add(server: SearchServerIndex) {
        if place == .city, translatedCityName == nil {
            translatedCityName = server.translatedCityName
        }
        underMaintenance = underMaintenance && server.underMaintenance
    }

    var asIndex: SearchCityIndex {
        SearchCityIndex(
            id: "\(name)-\(countryCode)",
            cityName: name,
            translatedCityName: translatedCityName,
            countryName: countryName,
            countryCode: countryCode,
            underMaintenance: underMaintenance
        )
    }
}

extension SearchRoot.State {
    var sections: IdentifiedArrayOf<CountrySectionFeature.State>? {
        switch self {
        case let .loading(searchData, _):
            searchData
        case .loaded:
            nil
        }
    }

    /// The text in the search field: the buffered keystrokes while the index is still being built, the
    /// live query once it has loaded.
    public var searchQuery: String {
        switch self {
        case let .loading(_, query):
            query
        case let .loaded(searchState):
            searchState.searchQuery
        }
    }
}
