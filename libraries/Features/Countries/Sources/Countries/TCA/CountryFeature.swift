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
import Dependencies
import Domain
import Foundation
import Localization
import Persistence
import VPNAppCore
import VPNShared

@Reducer
struct CountryFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let serverGroup: ServerGroupInfo
        let serverType: ServerType
        let showCountryConnectButton: Bool
        let showFeatureIcons: Bool
        let serversFilter: CountrySectionFeature.ServerFilter

        var id: String {
            switch serverGroup.kind {
            case let .city(name, code), let .state(name, code):
                name + code
            case let .country(code):
                code
            case let .gateway(name):
                name
            }
        }

        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userTier) var userTier: Int?

        // Server sections (Free, Plus, etc.)
        var serverSections: IdentifiedArrayOf<ServerSection.State> = []

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

        var countryName: String {
            switch serverGroup.kind {
            case let .country(code), let .city(_, code), let .state(_, code):
                LocalizationUtility.default.countryName(forCode: code) ?? ""
            case .gateway:
                ""
            }
        }

        var description: String {
            switch serverGroup.kind {
            case let .country(countryCode):
                LocalizationUtility.default.countryName(forCode: countryCode) ?? "Unavailable"
            case let .gateway(gatewayName):
                gatewayName
            case let .city(name, _):
                name
            case let .state(name, _):
                name
            }
        }

        var isUsersTierTooLow: Bool {
            switch serverGroup.kind {
            case .country, .city, .state:
                userTier?.isFreeTier == true
            case .gateway:
                false
            }
        }

        var underMaintenance: Bool {
            @Dependency(\.propertiesManager) var propertiesManager
            return serverGroup.isUnderMaintenance
                || serverGroup.protocolSupport.isDisjoint(with: propertiesManager.currentProtocolSupport)
        }

        var isConnected: Bool {
            guard case let .connected(_, actual) = vpnConnectionStatus,
                  let logical = actual?.server.logical else {
                return false
            }
            return serverGroup.matchesLogical(logical)
        }

        var isConnecting: Bool {
            guard case let .connecting(_, server) = vpnConnectionStatus,
                  let logical = server?.logical else {
                return false
            }
            return serverGroup.matchesLogical(logical)
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }

        var torAvailable: Bool {
            serverGroup.featureUnion.contains(.tor)
        }

        var p2pAvailable: Bool {
            serverGroup.featureUnion.contains(.p2p)
        }

        var isSmartAvailable: Bool {
            serverGroup.supportsSmartRouting
        }

        var streamingAvailable: Bool {
            !streamingServices.isEmpty
        }

        var streamingServices: [VpnStreamingOption] {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.streamingServices[countryCode]?["2"] ?? []
        }

        var alphaOfMainElements: Double {
            if underMaintenance {
                return 0.25
            }
            if isUsersTierTooLow {
                return 0.5
            }
            return 1.0
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case connectTapped
        case loadServers

        // Child actions
        case serverSection(IdentifiedActionOf<ServerSection>)

        // Connection actions
        case connectionStatusChanged(VPNConnectionStatus)

        case connectRequested(ServerGroupInfo.Kind, ServerType)
        case disconnectRequested
        case stopConnectingRequested
        case showCountryUpsell(String)
        case showMaintenanceAlert(String)
    }

    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.propertiesManager) private var propertiesManager

    var body: some ReducerOf<Self> {
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

            case .connectionStatusChanged:
                // Connection status is automatically updated via @SharedReader
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
        let protocolFilter = VPNServerFilter.supports(protocol: propertiesManager.currentProtocolSupport)
        let featureFilter = VPNServerFilter.features(propertiesManager.secureCoreToggle ? .secureCore : .standard)
        let filters = [kindFilter, featureFilter, protocolFilter]

        let servers = serverRepository.getServers(filteredBy: filters, orderedBy: .loadAscending)

        let freeServers = servers.filter(\.logical.tier.isFreeTier)
        let plusServers = servers.filter(\.logical.tier.isPaidTier)

        var sections: [ServerSection.State] = []

        if !freeServers.isEmpty {
            sections.append(
                ServerSection.State(
                    tier: 0,
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
                    tier: 2,
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
        let userTier = state.userTier ?? Int.freeTier
        let sortedSections = sections.sorted { section1, section2 in
            if userTier >= section1.tier && userTier >= section2.tier ||
                userTier < section1.tier && userTier < section2.tier {
                section1.tier > section2.tier
            } else {
                section1.tier < section2.tier
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
struct ServerSection {
    @ObservableState
    struct State: Equatable, Identifiable {
        let tier: Int
        var servers: IdentifiedArrayOf<ServerItemFeature.State>

        var id: String { servers.map(\.id).reduce("", +) }
    }

    enum Action {
        case servers(IdentifiedActionOf<ServerItemFeature>)
    }

    var body: some ReducerOf<Self> {
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
}
