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

import Announcement
import ComposableArchitecture
import ConnectionInventory
import CountriesShared
import Domain
import Localization
import Payments
import PaymentsShared
import Persistence
import Strings
import SwiftUI
import VPNAppCore

@Reducer
public struct CountriesListFeature: Sendable {
    @Reducer
    public enum Destination: Sendable {
        case featuresInfo(ServersFeaturesInformationFeature)
        case freeConnectionsInfo(FreeConnectionsFeature)
        case allCountriesUpsell(UpsellSheetFeature)
    }

    @ObservableState
    public struct State: Equatable {
        // The scroll position will not be adjusted after expanding the country for pre macOS 15.
        // This means that users in some cases might need to use the scroll wheel a bit.
        private var _scrollPosition: Any?
        @available(macOS 15.0, *)
        var scrollPosition: ScrollPosition {
            get { (_scrollPosition as? ScrollPosition) ?? ScrollPosition(edge: .top) }
            set { _scrollPosition = newValue }
        }

        var gateways: IdentifiedArrayOf<DesktopCityStateListFeature.State> = []
        var countries: IdentifiedArrayOf<DesktopCityStateListFeature.State> = []

        public var searchText: String = ""
        var isFreeTier: Bool {
            @SharedReader(.userTier) var userTier: Int?
            return userTier?.isFreeTier ?? false
        }

        // Stored so that we can collapse the previously expanded section
        var expandedCountryCode: String?

        var listState: ListState = .loading

        var offerBannerViewModel: OfferBannerViewModel?

        @SharedReader(.secureCoreToggle) var secureCore: Bool
        @Presents public var destination: Destination.State?

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

    public enum Action: BindableAction {
        case searchText(String)
        case binding(BindingAction<State>)
        case getGroups(secureCore: Bool)
        case loadingFinished(
            countries: IdentifiedArrayOf<DesktopCityStateListFeature.State>,
            gateways: IdentifiedArrayOf<DesktopCityStateListFeature.State>
        )
        case unselect
        case updateScrollPosition(code: String)
        case countries(IdentifiedActionOf<DesktopCityStateListFeature>)
        case gateways(IdentifiedActionOf<DesktopCityStateListFeature>)
        case infoButtonTappedCountries
        case infoButtonTappedGateways
        case infoButtonTappedFreeConnections
        case upsellBannerTapped
        case connectToFastest
        case listenForSecureCoreUpdates
        case loadOfferBanner
        case destination(PresentationAction<Destination.Action>)
    }

    public init() {}

    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.serverRepository) var repository
    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.announcementManager) var announcementManager
    @Dependency(\.sessionService) var sessionService
    @Dependency(\.linkOpener) var linkOpener

    private enum CancelID {
        case debounceRequest
        case watchSecureCoreToggle
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .connectToFastest:
                let spec = CityStateConnectionSpecFactory.makeSpec(location: .any(.fastest))
                return .run { _ in
                    try await connectToVPN(spec, nil, .quick)
                }
            case .upsellBannerTapped:
                state.destination = .allCountriesUpsell(.init(
                    modalType: .allCountries(
                        numberOfServers: repository.roundedServerCount,
                        numberOfCountries: repository.countryCount()
                    )
                ))
                return .none
            case .infoButtonTappedCountries:
                var infoState = ServersFeaturesInformationFeature.State.servicesInfo
                infoState.screenTitle = Localizable.featuresTitle
                state.destination = .featuresInfo(infoState)
                return .none
            case .infoButtonTappedGateways:
                var infoState = ServersFeaturesInformationFeature.State.gatewaysInfo
                infoState.screenTitle = Localizable.locationsGateways
                state.destination = .featuresInfo(infoState)
                return .none
            case .infoButtonTappedFreeConnections:
                state.destination = .freeConnectionsInfo(.init(countries: freeCountries()))
                return .none
            case .destination(.presented(.freeConnectionsInfo(.upgradeTapped))):
                state.destination = .allCountriesUpsell(.init(
                    modalType: .allCountries(
                        numberOfServers: repository.roundedServerCount,
                        numberOfCountries: repository.countryCount()
                    )
                ))
                return .none
            case .destination(.presented(.allCountriesUpsell(.upgradeTapped))):
                state.destination = nil
                return .run { _ in
                    guard let url = await sessionService.getPlanSession(mode: .upgrade) else {
                        return
                    }
                    await MainActor.run {
                        linkOpener.open(url)
                    }
                }
            case .destination(.presented(.allCountriesUpsell(.continueTapped))):
                state.destination = nil
                return .none
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .destination:
                return .none
            case .listenForSecureCoreUpdates:
                return .publisher {
                    state.$secureCore
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .removeDuplicates()
                        .map(Action.getGroups)
                }
                .cancellable(id: CancelID.watchSecureCoreToggle)
            case .loadOfferBanner:
                state.offerBannerViewModel = announcementManager.offerBannerViewModel { announcement in
                    announcementManager.markAsRead(notificationID: announcement.notificationID)
                }
                return .none
            case let .getGroups(secureCore):
                state.listState = .loading
                return .run { [search = state.searchText, expandedCode = state.expandedCountryCode] send in
                    await send(.loadOfferBanner)

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
                guard state.searchText != text else {
                    return .none
                }
                state.searchText = text
                return .send(.getGroups(secureCore: state.secureCore))
                    .debounce(
                        id: CancelID.debounceRequest,
                        for: 0.5,
                        scheduler: mainQueue
                    )
            }
        }
        .forEach(\.countries, action: \.countries) {
            DesktopCityStateListFeature()
        }
        .forEach(\.gateways, action: \.gateways) {
            DesktopCityStateListFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }

    func groups(
        with kind: VPNServerFilter.ServerTypeFilter,
        search: String,
        expandedCountryCode: String?,
        secureCore: Bool
    ) -> IdentifiedArrayOf<DesktopCityStateListFeature.State> {
        let groups = repository
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
        let states = groups.map {
            DesktopCityStateListFeature.State(
                groupInfo: $0,
                search: search,
                expandedCode: expandedCountryCode,
                secureCore: secureCore
            )
        }
        return .init(uniqueElements: states)
    }

    private func freeCountries() -> IdentifiedArrayOf<FreeConnectionsFeature.State.Country> {
        let serverGroups = repository.getGroups(filteredBy: [.tier(.exact(tier: 0))], groupedBy: .serverType)
        var seenCountryCodes = Set<String>()

        let countries = serverGroups.compactMap { serverGroup -> FreeConnectionsFeature.State.Country? in
            let countryCode: String? = switch serverGroup.kind {
            case let .country(code), let .city(_, code), let .state(_, code):
                code
            case .gateway:
                nil
            }

            guard let countryCode,
                  serverGroup.minTier.isFreeTier,
                  !seenCountryCodes.contains(countryCode) else {
                return nil
            }

            seenCountryCodes.insert(countryCode)
            return .init(
                code: countryCode,
                name: LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable
            )
        }

        return IdentifiedArray(uniqueElements: countries)
    }
}

extension CountriesListFeature.Destination.State: Equatable {}
public extension CountriesListFeature.State {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.gateways == rhs.gateways &&
            lhs.countries == rhs.countries &&
            lhs.searchText == rhs.searchText &&
            lhs.expandedCountryCode == rhs.expandedCountryCode &&
            lhs.listState == rhs.listState &&
            lhs.offerBannerViewModel == rhs.offerBannerViewModel &&
            lhs.secureCore == rhs.secureCore &&
            lhs.destination == rhs.destination
    }
}
