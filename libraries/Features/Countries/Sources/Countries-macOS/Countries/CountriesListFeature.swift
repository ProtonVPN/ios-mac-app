//
//  Created on 2026-01-13 by Pawel Jurczyk.
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
import ConnectionInventory
import CountriesShared
import Domain
import Persistence
import Strings
import SwiftUI
import VPNAppCore

@Reducer
public struct CountriesListFeature: Sendable {
    @ObservableState
    public struct State {
        // The scroll position will not be adjusted after expanding the country for pre macOS 15.
        // This means that users in some cases might need to use the scroll wheel a bit.
        private var _scrollPosition: Any?
        @available(macOS 15.0, *)
        var scrollPosition: ScrollPosition {
            get { (_scrollPosition as? ScrollPosition) ?? ScrollPosition(edge: .top) }
            set { _scrollPosition = newValue }
        }

        public var gateways: IdentifiedArrayOf<CityStateListFeature.State> = []
        public var countries: IdentifiedArrayOf<CityStateListFeature.State> = []

        var searchText: String = ""
        var isFreeTier: Bool {
            @SharedReader(.userTier) var userTier: Int?
            return userTier?.isFreeTier ?? false
        }

        // Stored so that we can collapse the previously expanded section
        var expandedCountryCode: String?

        var listState: ListState = .loading

        @SharedReader(.secureCoreToggle) var secureCore: Bool

        var serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability {
            @Dependency(\.serverChangeAuthorizer) var authorizer
            return authorizer.serverChangeAvailability()
        }

        enum ListState: Equatable {
            case loading
            case loaded
        }

        public init() {
            if #available(macOS 15, *) {
                _scrollPosition = ScrollPosition(edge: .top)
            }
        }
    }

    public var displayPremiumServices: (@Sendable () -> Void)?
    public var displayGatewaysServices: (@Sendable () -> Void)?
    public var displayUpsellModal: (@Sendable () -> Void)?
    public var displayFreeConnectionsInfo: (@Sendable () -> Void)?

    public enum Action: BindableAction {
        case searchText(String)
        case binding(BindingAction<State>)
        case didAppear
        case getGroups
        case loadingFinished(countries: IdentifiedArrayOf<CityStateListFeature.State>, gateways: IdentifiedArrayOf<CityStateListFeature.State>)
        case unselect
        case updateScrollPosition(code: String)
        case countries(IdentifiedActionOf<CityStateListFeature>)
        case gateways(IdentifiedActionOf<CityStateListFeature>)
        case infoButtonTappedCountries
        case infoButtonTappedGateways
        case infoButtonTappedFreeConnections
        case upsellBannerTapped
        case connectToFastest
    }

    public init() {}

    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.serverRepository) var repository
    @Dependency(\.connectToVPN) var connectToVPN

    private enum CancelID {
        case debounceRequest
        case watchSecureCoreToggle
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .connectToFastest:
                let spec = ConnectionSpec(location: .any(.fastest), features: [])
                return .run { _ in
                    try await connectToVPN(spec, nil, .quick)
                }
            case .upsellBannerTapped:
                displayUpsellModal?()
                return .none
            case .infoButtonTappedCountries:
                displayPremiumServices?()
                return .none
            case .infoButtonTappedGateways:
                displayGatewaysServices?()
                return .none
            case .infoButtonTappedFreeConnections:
                displayFreeConnectionsInfo?()
                return .none
            case .didAppear:
                return .publisher {
                    state.$secureCore
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map { _ in .getGroups }
                }
                .cancellable(id: CancelID.watchSecureCoreToggle)
            case .getGroups:
                state.listState = .loading
                return .run { [search = state.searchText, expandedCode = state.expandedCountryCode, secureCore = state.secureCore] send in
                    let countries = groups(
                        with: .country,
                        search: search,
                        expandedCountryCode: expandedCode,
                        secureCore: secureCore
                    )
                    let gateways = groups(
                        with: .gateway,
                        search: search,
                        expandedCountryCode: expandedCode,
                        secureCore: secureCore
                    )
                    await send(.loadingFinished(countries: countries, gateways: gateways))
                }
            case let .loadingFinished(countries, gateways):
                state.countries = countries
                state.gateways = gateways
                state.listState = .loaded
                return .none
            case .unselect:
                state.expandedCountryCode = nil
                return .none
            case let .countries(.element(id, action: .expand)),
                 let .gateways(.element(id, action: .expand)):
                if let code = state.expandedCountryCode {
                    state.countries[id: code]?.isExpanded = false // collapse the previous one
                    state.gateways[id: code]?.isExpanded = false // collapse the previous one
                    if code == id {
                        state.expandedCountryCode = nil // none is expanded
                    } else {
                        state.expandedCountryCode = id // mark the new expanded one
                        return .send(.updateScrollPosition(code: id))
                    }
                } else {
                    state.expandedCountryCode = id
                    return .send(.updateScrollPosition(code: id))
                }
                return .none
            case let .updateScrollPosition(code):
                if #available(macOS 15.0, *) {
                    state.scrollPosition.scrollTo(id: code)
                }
                return .none
            case .gateways:
                return .none
            case .countries:
                return .none
            case .binding:
                return .none
            case let .searchText(text):
                guard state.searchText != text else { return .none }
                state.searchText = text
                return .send(.getGroups)
                    .debounce(
                        id: CancelID.debounceRequest,
                        for: 0.5,
                        scheduler: mainQueue
                    )
            }
        }
        .forEach(\.countries, action: \.countries) {
            CityStateListFeature()
        }
        .forEach(\.gateways, action: \.gateways) {
            CityStateListFeature()
        }
    }

    func groups(
        with kind: VPNServerFilter.ServerTypeFilter,
        search: String,
        expandedCountryCode: String?,
        secureCore: Bool
    ) -> IdentifiedArrayOf<CityStateListFeature.State> {
        let gatewaysGroups = repository
            .getGroups(
                filteredBy: [
                    .kind(kind),
                    .isNotUnderMaintenance,
                    .features(secureCore ? .secureCore : .standard),
                    .matches(search),
                    ProtocolFilters().supportedProtocolsFilter,
                ],
                groupedBy: .serverType
            )
        let states = gatewaysGroups.map {
            CityStateListFeature.State(
                groupInfo: $0,
                search: search,
                expandedCode: expandedCountryCode,
                secureCore: secureCore
            )
        }
        return .init(uniqueElements: states)
    }
}
