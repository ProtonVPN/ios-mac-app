//
//  Created on 08/01/2026 by Max Kupetskyi.
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
import Connection
import Dependencies
import Domain
import Foundation
import Localization
import Persistence
import VPNAppCore
import VPNShared

@Reducer
public struct CountryFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        public let serverGroup: ServerGroupInfo
        let serverType: ServerType
        public let showCountryConnectButton: Bool
        public let showFeatureIcons: Bool
        let serversFilter: CountrySectionFeature.ServerFilter

        public var id: String {
            let kindID = switch serverGroup.kind {
            case let .city(name, code):
                "city-\(name)-\(code)"
            case let .state(name, code):
                "state-\(name)-\(code)"
            case let .country(code):
                "country-\(code)"
            case let .gateway(name):
                "gateway-\(name)"
            }

            return [
                kindID,
                "features-\(serverGroup.featureIntersection.rawValue)",
                "minTier-\(serverGroup.minTier)",
                "maxTier-\(serverGroup.maxTier)",
                "servers-\(serverGroup.serverCount)",
                "serverType-\(serverType)",
                "filter-\(serversFilter)",
            ].joined(separator: "|")
        }

        @SharedReader(.connectionState) var connectionState: ConnectionState
        @SharedReader(.userTier) var userTier: VpnTier?

        // Server sections (Free, Plus, etc.)
        public internal(set) var serverSections: IdentifiedArrayOf<ServerSection.State> = []

        // City groupings for Search
        var cities: IdentifiedArrayOf<CityFeature.State> = []

        // Computed properties
        var countryCode: String {
            switch serverGroup.kind {
            case let .country(code), let .city(_, code), let .state(_, code):
                code
            case .gateway:
                ""
            }
        }

        public var countryName: String {
            switch serverGroup.kind {
            case let .country(code), let .city(_, code), let .state(_, code):
                LocalizationUtility.default.countryName(forCode: code) ?? ""
            case .gateway:
                ""
            }
        }

        var isUsersTierTooLow: Bool {
            switch serverGroup.kind {
            case .country, .city, .state:
                userTier.isFree
            case .gateway:
                false
            }
        }

        public var isGateway: Bool {
            serverGroup.kind.isGateway
        }

        var underMaintenance: Bool {
            serverGroup.isUnderMaintenance
                || serverGroup.protocolSupport.isDisjoint(with: currentProtocolSupport())
        }

        var isConnected: Bool {
            guard case let .connected(_, connectionData) = connectionState else {
                return false
            }
            return serverGroup.matchesLogical(connectionData.currentPeer.logical)
        }

        var isConnecting: Bool {
            switch connectionState {
            case let .connecting(.resolved(resolvedIntent), _),
                 let .authenticationRequired(.resolved(resolvedIntent), _):
                serverGroup.matches(location: resolvedIntent.spec.location, logical: nil)

            case let .connecting(.unresolved(unresolvedIntent), _),
                 let .authenticationRequired(.unresolved(unresolvedIntent), _):
                serverGroup.matches(location: unresolvedIntent.spec.location, logical: nil)

            default:
                false
            }
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }

        var streamingServices: [VpnStreamingOption] {
            @SharedReader(.streamingServices) var streamingServices
            return streamingServices[countryCode]?["2"] ?? []
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case rowTapped
        case connectTapped
        case loadServers

        // Child actions
        case serverSection(IdentifiedActionOf<ServerSection>)

        // Connection actions
        case connectionStateChanged(ConnectionState)

        case connectRequested(ServerGroupInfo.Kind, ServerType)
        case disconnectRequested
        case stopConnectingRequested
        case showCountryUpsell(String)
        case showMaintenanceAlert(String)
    }

    @Dependency(\.serverRepository) private var serverRepository

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadServers)

            case .loadServers:
                state.serverSections = loadServerSections(for: state)
                state.cities = loadCities(for: state)
                return .none

            case .connectTapped:
                return handleConnect(state: state)

            case .rowTapped:
                return .none

            case .connectionStateChanged:
                // Connection state is automatically updated via @SharedReader
                return .none

            case .serverSection:
                return .none

            case .binding:
                return .none

            case .connectRequested, .disconnectRequested, .stopConnectingRequested, .showCountryUpsell, .showMaintenanceAlert:
                return .none
            }
        }
        .forEach(\.serverSections, action: \.serverSection) {
            ServerSection()
        }
    }

    // MARK: - Private Methods

    private func handleConnect(state: State) -> Effect<Action> {
        print("Connect requested by clicking on Country item")

        if state.isUsersTierTooLow {
            print("Connect rejected because user plan is too low")
            return .send(.showCountryUpsell(state.countryCode))
        }

        if state.underMaintenance {
            print("Connect rejected because server is in maintenance")
            return .send(.showMaintenanceAlert(state.countryName))
        }

        if state.isConnected {
            print("VPN is connected already. Will be disconnected.")
            return .send(.disconnectRequested)
        }

        if state.isConnecting {
            print("VPN is connecting. Will stop connecting.")
            return .send(.stopConnectingRequested)
        }

        print("Will connect to \(state.serverGroup.kind) serverType: \(state.serverType)")
        return .send(.connectRequested(state.serverGroup.kind, state.serverType))
    }

    private func loadServerSections(for state: State) -> IdentifiedArrayOf<ServerSection.State> {
        let kindFilter = state.serverGroup.kind.filter
        let protocolFilter = VPNServerFilter.supports(protocol: currentProtocolSupport())
        let featureFilter = VPNServerFilter.features(ServerType.current == .secureCore ? .secureCore : .standard)
        let filters = [kindFilter, featureFilter, protocolFilter]

        let servers = serverRepository.getServers(filteredBy: filters, orderedBy: .loadAscending)

        let freeServers = servers.filter(\.logical.tier.isFree)
        let plusServers = servers.filter(\.logical.tier.isPaid)

        var sections: [ServerSection.State] = []

        if !freeServers.isEmpty {
            sections.append(
                ServerSection.State(
                    tier: ServerTier.free,
                    servers: IdentifiedArray(
                        uniqueElements: freeServers.map { serverInfo in
                            ServerItemFeature.State(
                                serverInfo: serverInfo,
                                serverType: state.serverType
                            )
                        }
                    )
                )
            )
        }

        if !plusServers.isEmpty {
            sections.append(
                ServerSection.State(
                    tier: ServerTier.plus,
                    servers: IdentifiedArray(
                        uniqueElements: plusServers.map { serverInfo in
                            ServerItemFeature.State(
                                serverInfo: serverInfo,
                                serverType: state.serverType
                            )
                        }
                    )
                )
            )
        }

        // Sort sections: available tiers first, then by tier descending
        let userTier = (state.userTier ?? .free).rawValue
        let sortedSections = sections.sorted { section1, section2 in
            if userTier >= section1.tier.rawValue && userTier >= section2.tier.rawValue ||
                userTier < section1.tier.rawValue && userTier < section2.tier.rawValue {
                section1.tier.rawValue > section2.tier.rawValue
            } else {
                section1.tier.rawValue < section2.tier.rawValue
            }
        }

        return IdentifiedArray(uniqueElements: sortedSections)
    }

    private func loadCities(for state: State) -> IdentifiedArrayOf<CityFeature.State> {
        guard case .country = state.serverGroup.kind else {
            return []
        }

        let allServers = state.serverSections.flatMap(\.servers)
        let serversWithCity = allServers.filter { !$0.city.isEmpty }

        let groups = Dictionary(grouping: serversWithCity, by: { $0.city })

        let cityStates = groups.map { cityName, servers in
            CityFeature.State(
                cityName: cityName,
                countryCode: state.countryCode,
                servers: IdentifiedArray(uniqueElements: servers)
            )
        }.sorted { $0.cityName < $1.cityName }

        return IdentifiedArray(uniqueElements: cityStates)
    }
}

// MARK: - ServerSection Reducer

@Reducer
public struct ServerSection {
    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        let tier: ServerTier
        public internal(set) var servers: IdentifiedArrayOf<ServerItemFeature.State>

        public var id: String {
            servers.map(\.id).reduce("", +)
        }

        public var title: String {
            tier.title
        }
    }

    public enum Action {
        case servers(IdentifiedActionOf<ServerItemFeature>)
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .servers:
                .none
            }
        }
        .forEach(\.servers, action: \.servers) {
            ServerItemFeature()
        }
    }
}

// MARK: - Helper Extensions

private extension ServerGroupInfo {
    func matchesLogical(_ logical: Logical) -> Bool {
        switch kind {
        case let .gateway(name):
            logical.kind == .gateway(name: name)
        case let .country(code) where code == logical.exitCountryCode:
            switch (featureIntersection == .secureCore, logical.kind) {
            case (true, .secureCore), (false, .country):
                true
            default:
                false
            }
        default:
            false
        }
    }

    func matches(location: ConnectionSpec.Location, logical: Logical?) -> Bool {
        switch location {
        case let .gateway(name):
            kind == .gateway(name: name)

        case .any:
            logical.map { matchesLogical($0) } ?? false

        case let .country(code, _):
            kind == .country(code: code)

        case let .city(name, code, _):
            kind == .city(name: name, code: code)

        case let .state(name, code, order):
            kind == .state(name: name, code: code)

        case let .exact(_, logicalID, number, subregion, regionCode):
            logical.map { matchesLogical($0) } ?? false

        case .secureCore(.any):
            logical.map { matchesLogical($0) } ?? false

        case let .secureCore(.anyHop(to, _)):
            kind == .country(code: to)

        case let .secureCore(.hop(to, via)):
            kind == .country(code: to)
        }
    }
}
