//
//  Created on 12/01/2026 by Max Kupetskyi.
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
import Strings

@Reducer
struct CountriesMainFeature {
    @ObservableState
    enum State {
        case loading
        case standard(CountriesFeature.State)
        case secureCore(CountriesFeature.State)
    }

    enum Action {
        case standard(CountriesFeature.Action)
        case secureCore(CountriesFeature.Action)

        case onAppear

        // Server type toggle
        case toggleServerType
        case setServerType(ServerType)

        // Content reload
        case reloadContent
        case serverListUpdated
    }

    private enum CancelID {
        case observeServerList
        case appEvents
    }

    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.propertiesManager) private var propertiesManager

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state = .loading
                return Effect.merge(
                    .send(.reloadContent),
                    observeServerListUpdates(),
                    observeAppEvents()
                )

            case .toggleServerType:
                let serverType = propertiesManager.serverTypeToggle
                let newType: ServerType = serverType == .secureCore ? .standard : .secureCore
                return .send(.setServerType(newType))

            case .setServerType:
                return .send(.reloadContent)

            case .reloadContent:
                state = .loading
                let serverType = propertiesManager.serverTypeToggle
                let sections = buildSections()
                switch serverType {
                case .standard, .p2p, .tor, .unspecified:
                    state = .standard(.init(sections: sections, isSecureCore: false))
                case .secureCore:
                    state = .secureCore(.init(sections: sections, isSecureCore: true))
                }
                return .none

            case .serverListUpdated:
                return .send(.reloadContent)

            case .standard(.secureCoreToggled),
                 .secureCore(.secureCoreToggled):
                return .send(.toggleServerType)

            case .standard, .secureCore:
                return .none
            }
        }
        .ifCaseLet(\.standard, action: \.standard) {
            CountriesFeature()
        }
        .ifCaseLet(\.secureCore, action: \.secureCore) {
            CountriesFeature()
        }
    }

    // MARK: - Private Methods

    private func buildSections() -> IdentifiedArrayOf<CountrySectionFeature.State> {
        let serverType = propertiesManager.serverTypeToggle
        @SharedReader(.userTier) var userTier: Int?

        var sections: [CountrySectionFeature.State] = []

        let groups = serverRepository.getGroups(
            filteredBy: [.features(serverType.serverTypeFilter)],
            groupedBy: .serverType
        )

        // Separate gateways from countries
        let gatewayGroups = groups.filter { group in
            switch group.kind {
            case .gateway: true
            default: false
            }
        }

        let countryGroups = groups.filter { group in
            switch group.kind {
            case .country: true
            default: false
            }
        }

        // Build gateway section if applicable
        if !gatewayGroups.isEmpty {
            let gatewayRows = gatewayGroups.map { group in
                RowFeature.State.country(
                    CountryFeature.State(
                        serverGroup: group,
                        serverType: serverType,
                        showCountryConnectButton: true,
                        showFeatureIcons: false,
                        serversFilter: .restricted
                    )
                )
            }

            sections.append(
                CountrySectionFeature.State(
                    id: .gateway,
                    type: .gateway,
                    title: Localizable.locationsGateways,
                    rows: IdentifiedArray(uniqueElements: gatewayRows),
                    hasInfoButton: true,
                    serversFilter: .restricted
                )
            )
        }

        // Build profile/country sections based on user tier
        if userTier?.isFreeTier == true {
            buildFreeTierSections(
                countryGroups: countryGroups,
                serverType: serverType,
                sections: &sections
            )
        } else {
            buildPaidTierSections(
                countryGroups: countryGroups,
                serverType: serverType,
                sections: &sections
            )
        }

        return IdentifiedArray(uniqueElements: sections)
    }

    private func buildFreeTierSections(
        countryGroups: [ServerGroupInfo],
        serverType: ServerType,
        sections: inout [CountrySectionFeature.State]
    ) {
        // Profiles section with "Fastest" connection
        let fastestProfile = RowFeature.State.profile(
            DefaultProfileFeature.State(
                serverOffering: .fastest(nil),
                extraMargin: false
            )
        )

        if !countryGroups.isEmpty {
            sections.append(
                CountrySectionFeature.State(
                    id: .freeProfiles,
                    type: .profiles,
                    title: Localizable.connectionsFreeWithCount(1),
                    rows: IdentifiedArray(uniqueElements: [fastestProfile]),
                    hasInfoButton: true,
                    serversFilter: .none
                )
            )
        }

        // Countries section with upsell banner
        let upsellBanner = RowFeature.State.banner(
            BannerFeature.State(bannerType: .upsell)
        )

        let countryRows = [upsellBanner] + countryGroups.map { group in
            RowFeature.State.country(
                CountryFeature.State(
                    serverGroup: group,
                    serverType: serverType,
                    showCountryConnectButton: true,
                    showFeatureIcons: true,
                    serversFilter: .default
                )
            )
        }

        let countryCount = countryRows.count - 1 // Subtract banner
        let title = countryCount != 0 ? Localizable.connectionsPaidWithCount(countryCount) : nil

        sections.append(
            CountrySectionFeature.State(
                id: .paidCountries,
                type: .countries,
                title: title,
                rows: IdentifiedArray(uniqueElements: countryRows),
                hasInfoButton: false,
                serversFilter: .default
            )
        )
    }

    private func buildPaidTierSections(
        countryGroups: [ServerGroupInfo],
        serverType: ServerType,
        sections: inout [CountrySectionFeature.State]
    ) {
        guard !countryGroups.isEmpty else { return }

        let fastestProfile = RowFeature.State.profile(
            DefaultProfileFeature.State(
                serverOffering: .fastest(nil),
                extraMargin: true
            )
        )

        let countryRows = [fastestProfile] + countryGroups.map { group in
            RowFeature.State.country(
                CountryFeature.State(
                    serverGroup: group,
                    serverType: serverType,
                    showCountryConnectButton: true,
                    showFeatureIcons: true,
                    serversFilter: .default
                )
            )
        }

        sections.append(
            CountrySectionFeature.State(
                id: .allCountries,
                type: .countries,
                title: "\(Localizable.locationsAll) (\(countryRows.count))",
                rows: IdentifiedArray(uniqueElements: countryRows),
                hasInfoButton: false,
                serversFilter: .default
            )
        )
    }

    private func observeServerListUpdates() -> Effect<Action> {
        .run { send in
            for await _ in NotificationCenter.default.notifications(named: ServerListUpdateNotification.name) {
                await send(.serverListUpdated)
            }
        }
        .cancellable(id: CancelID.observeServerList)
    }

    private func observeAppEvents() -> Effect<Action> {
        .run { send in
            let reloadEvents: [AppEvent] = [
                // .activeServerTypeChanged, // Shouldn't be needed, we can handle Toggle actions directly and/or get it from Shared property
                .planChanged,
                .vpnProtocol,
                .smartProtocol,
            ]

            await withTaskGroup(of: Void.self) { group in
                for event in reloadEvents {
                    let eventName = event.name
                    group.addTask {
                        for await _ in NotificationCenter.default.notifications(named: eventName) {
                            await send(.reloadContent)
                        }
                    }
                }
            }
        }
        .cancellable(id: CancelID.appEvents)
    }
}
