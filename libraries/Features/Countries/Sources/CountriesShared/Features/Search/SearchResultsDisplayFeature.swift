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
import Connection
import ConnectionInventory
import Domain
import Persistence

@Reducer
public struct SearchResultsDisplayFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var rows: IdentifiedArrayOf<SearchResultRow>
        public var searchText: String = ""
        public var isFree: Bool = false

        @SharedReader(.connectionState) var connectionState: ConnectionState

        public var numberOfCountries: Int {
            @Dependency(\.serverRepository) var repository
            return repository.countryCount()
        }

        /// Whether the tunnel is in the row, or is on its way there
        public func isCurrentlyConnected(_ row: SearchResultRow) -> Bool {
            if let logical = connectionState.currentLogical {
                return row.matches(logical: logical)
            }
            if let location = connectionState.location {
                return row.matches(location: location)
            }
            return false
        }
    }

    public enum Action: Equatable {
        // Selection actions
        case countrySelected(SearchCountryIndex)
        case countryConnectTapped(SearchCountryIndex)
        case citySelected(SearchCityIndex)
        case stateSelected(SearchCityIndex)
        case serverSelected(SearchServerIndex)

        // Upsell
        case showUpsell
        case showCountryUpsell(String)
        case delegate(Delegate)

        @CasePathable
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
            case let .countrySelected(country):
                if state.isFree, case let .country(countryCode) = country.kind {
                    return .send(.delegate(.showCountryUpsell(countryCode)))
                }
                return .send(.delegate(.navigateTo(country.kind)))

            case let .countryConnectTapped(country):
                if state.isFree, case let .country(countryCode) = country.kind {
                    return .send(.delegate(.showCountryUpsell(countryCode)))
                }
                return toggleConnection(state: state, row: .country(country), trigger: .searchCountry)

            case let .citySelected(city):
                if state.isFree {
                    return .send(.delegate(.showCountryUpsell(city.countryCode)))
                }
                return toggleConnection(state: state, row: .city(city), trigger: .searchCity)

            case let .stateSelected(stateItem):
                if state.isFree {
                    return .send(.delegate(.showCountryUpsell(stateItem.countryCode)))
                }
                return toggleConnection(state: state, row: .state(stateItem), trigger: .searchState)

            case let .serverSelected(server):
                if server.isUsersTierTooLow {
                    return .send(.delegate(.showUpsell))
                }
                return toggleConnection(state: state, row: server.row, trigger: .searchServer)

            case .showUpsell:
                return .send(.delegate(.showUpsell))

            case let .showCountryUpsell(countryCode):
                return .send(.delegate(.showCountryUpsell(countryCode)))

            case .delegate:
                return .none
            }
        }
    }

    /// Connect or disconnect
    private func toggleConnection(
        state: State,
        row: SearchResultRow,
        trigger: UserInitiatedVPNChange.VPNTrigger
    ) -> Effect<Action> {
        if state.isCurrentlyConnected(row) {
            return .send(.delegate(.disconnectRequested(trigger)))
        }
        if let scope = row.maintenanceScope {
            return .send(.delegate(.showMaintenanceAlert(scope)))
        }
        guard let location = row.connectionLocation else {
            return .none
        }
        let spec = CityStateConnectionSpecFactory.makeSpec(location: location)
        return .send(.delegate(.connectRequested(spec, trigger)))
    }
}

public enum SearchResultRow: Equatable, Identifiable, Sendable {
    case sectionHeader(String)
    case upsell
    case country(SearchCountryIndex)
    case city(SearchCityIndex)
    case state(SearchCityIndex)
    case secureCoreCountry(SearchServerIndex)
    case server(SearchServerIndex)

    public var id: String {
        switch self {
        case let .sectionHeader(title):
            "header-\(title)"
        case .upsell:
            "upsell"
        case let .country(state):
            "country-\(state.id)"
        case let .city(state):
            "city-\(state.id)"
        case let .state(state):
            "state-\(state.id)"
        case let .secureCoreCountry(state):
            "secureCoreCountry-\(state.id)"
        case let .server(state):
            "server-\(state.id)"
        }
    }
}

public extension SearchResultRow {
    var maintenanceScope: SearchMaintenanceScope? {
        switch self {
        case let .country(country):
            guard country.underMaintenance else { return nil }
            return country.kind.isGateway ? .gateway : .country

        case let .city(city):
            return city.underMaintenance ? .city : nil

        case let .state(stateItem):
            return stateItem.underMaintenance ? .state : nil

        case let .server(server), let .secureCoreCountry(server):
            return server.underMaintenance ? .server : nil

        case .sectionHeader, .upsell:
            return nil
        }
    }

    var groupKind: ServerGroupInfo.Kind? {
        switch self {
        case let .country(country):
            country.kind
        case let .city(city):
            .city(name: city.cityName, code: city.countryCode)
        case let .state(stateItem):
            .state(name: stateItem.cityName, code: stateItem.countryCode)
        case .server, .secureCoreCountry, .sectionHeader, .upsell:
            nil
        }
    }

    var serverIndex: SearchServerIndex? {
        switch self {
        case let .server(server), let .secureCoreCountry(server):
            server
        case .country, .city, .state, .sectionHeader, .upsell:
            nil
        }
    }

    var connectionLocation: ConnectionSpec.Location? {
        if let groupKind {
            // Also covers a gateway, which connects to the gateway rather than to a country.
            return groupKind.locationWithOrder()
        }
        guard let server = serverIndex else {
            return nil
        }
        return CityStateConnectionSpecFactory.serverLocation(
            tier: server.tier == .free ? .free : .paid,
            logicalID: server.id,
            number: nil,
            subregion: server.cityName,
            exitCountryCode: server.exitCountryCode,
            entryCountryCode: server.entryCountryCode
        )
    }

    func matches(logical: Logical) -> Bool {
        if let groupKind {
            return groupKind.holds(logical)
        }
        guard let server = serverIndex else {
            return false
        }
        guard let entryCountryCode = server.entryCountryCode else {
            return logical.id == server.id
        }
        return logical.kind == .secureCore(entryCountryCode: entryCountryCode)
            && logical.exitCountryCode == server.exitCountryCode
    }

    /// Whether a request for `location` is a request for this row
    func matches(location: ConnectionSpec.Location) -> Bool {
        if let groupKind {
            return groupKind.matches(location: location)
        }
        guard let server = serverIndex else {
            return false
        }
        guard let entryCountryCode = server.entryCountryCode else {
            guard case let .exact(_, logicalID, _, _, _) = location else {
                return false
            }
            return logicalID == server.id
        }
        guard case let .secureCore(.hop(to, via)) = location else {
            return false
        }
        return to == server.exitCountryCode && via == entryCountryCode
    }
}

extension SearchServerIndex {
    var row: SearchResultRow {
        entryCountryCode == nil ? .server(self) : .secureCoreCountry(self)
    }
}
