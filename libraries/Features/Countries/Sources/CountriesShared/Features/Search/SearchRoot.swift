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

                    let (cities, states, freeServers, plusServers) = try Self.computeSearchableData()
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

    /// Computes all searchable data once.
    /// Returns: (cities, states, freeServers, plusServers)
    ///
    /// The database computes the city and state groups, their translated names, their display order, and
    /// their maintenance aggregates, so the index build runs three statements instead of one server query
    /// per country.
    private static func computeSearchableData() throws -> (cities: [SearchCityIndex], states: [SearchCityIndex], freeServers: [SearchServerIndex], plusServers: [SearchServerIndex]) {
        @Dependency(\.serverRepository) var serverRepository
        @SharedReader(.secureCoreToggle) var isSecureCore: Bool
        @SharedReader(.userTier) var userTier: VpnTier?

        let serverType: ServerType = isSecureCore ? .secureCore : .standard
        let protocolFilter = VPNServerFilter.supports(protocol: currentProtocolSupport())
        let featureFilter = VPNServerFilter.features(isSecureCore ? .secureCore : .standard)
        // Gateways carry no city or state, so the group queries exclude them the way the map's does.
        let groupFilters = [featureFilter, protocolFilter, VPNServerFilter.kind(.country(code: nil))]

        let cities = serverRepository
            .getGroups(filteredBy: groupFilters, groupedBy: .cityName, orderedBy: .localizedGroupNameAscending)
            .compactMap(placeIndex(for:))
        try Task.checkCancellation()

        let states = serverRepository
            .getGroups(filteredBy: groupFilters, groupedBy: .stateName, orderedBy: .localizedGroupNameAscending)
            .compactMap(placeIndex(for:))
        try Task.checkCancellation()

        var freeServers: [SearchServerIndex] = []
        var plusServers: [SearchServerIndex] = []
        for serverInfo in serverRepository.getServers(filteredBy: [featureFilter, protocolFilter], orderedBy: .nameAscending) {
            let server = buildServerIndex(
                serverInfo: serverInfo,
                serverType: serverType,
                userTier: userTier ?? .free,
                underMaintenance: serverInfo.logical.isUnderMaintenance
                    || serverInfo.protocolSupport.isDisjoint(with: currentProtocolSupport())
            )

            if server.tier == .free {
                freeServers.append(server)
            } else {
                plusServers.append(server)
            }
        }

        return (cities, states, freeServers, plusServers)
    }

    /// The search row for a city or state group, or nil for any other grouping the query returns.
    private static func placeIndex(for group: ServerGroupInfo) -> SearchCityIndex? {
        let name: String
        let code: String
        let translatedName: String?
        switch group.kind {
        case let .city(cityName, countryCode):
            name = cityName
            code = countryCode
            translatedName = group.translatedCity
        case let .state(stateName, countryCode):
            name = stateName
            code = countryCode
            translatedName = nil
        case .country, .gateway:
            return nil
        }
        return SearchCityIndex(
            id: "\(name)-\(code)",
            cityName: name,
            translatedCityName: translatedName,
            countryName: LocalizationUtility.default.countryName(forCode: code) ?? "",
            countryCode: code,
            underMaintenance: group.isUnderMaintenance
                || group.protocolSupport.isDisjoint(with: currentProtocolSupport())
        )
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
            sequence: logical.serverNameComponents.sequence,
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
