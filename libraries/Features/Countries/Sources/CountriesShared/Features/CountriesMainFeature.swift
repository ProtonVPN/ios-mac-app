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
public struct CountriesMainFeature {
    public init() {}

    @ObservableState
    public enum State: Equatable {
        case loading
        case standard(CountriesFeature.State)
        case secureCore(CountriesFeature.State)
    }

    public enum Action {
        case standard(CountriesFeature.Action)
        case secureCore(CountriesFeature.Action)

        case onAppear

        // Content reload
        case reloadContent
        case contentReloaded(ServerType, IdentifiedArrayOf<CountrySectionFeature.State>)
        case planChanged
    }

    private enum CancelID {
        case appEvents
    }

    @Shared(.secureCoreToggle) private var secureCoreToggle

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state = .loading
                return Effect.merge(
                    .send(.reloadContent),
                    observePlanChangedEvent()
                )

            case .reloadContent:
                state = .loading
                // Capture the current toggle snapshot for background section building.
                let secureCoreToggle = secureCoreToggle
                return .run { send in
                    let serverType = secureCoreToggle ? ServerType.secureCore : .standard
                    let sections = Self.buildSections(secureCoreToggle: secureCoreToggle)
                    await send(.contentReloaded(serverType, sections))
                }

            case let .contentReloaded(serverType, sections):
                switch serverType {
                case .standard, .p2p, .tor, .unspecified:
                    state = .standard(.init(sections: sections))
                case .secureCore:
                    state = .secureCore(.init(sections: sections))
                }
                return .none

            case .planChanged:
                return .send(.reloadContent)

            case .standard(.applySecureCoreToggle),
                 .secureCore(.applySecureCoreToggle):
                let newSecureCoreToggle = !secureCoreToggle
                $secureCoreToggle.withLock { $0 = newSecureCoreToggle }
                return .send(.reloadContent)

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

    // MARK: - Private observe methods

    private func observePlanChangedEvent() -> Effect<Action> {
        .run { send in
            for await _ in NotificationCenter.default.notifications(named: AppEvent.planChanged.name) {
                await send(.planChanged)
            }
        }
        .cancellable(id: CancelID.appEvents)
    }

    // MARK: - Private static build Methods

    private static func buildSections(secureCoreToggle: Bool) -> IdentifiedArrayOf<CountrySectionFeature.State> {
        @Dependency(\.serverRepository) var serverRepository
        let serverType = secureCoreToggle ? ServerType.secureCore : .standard
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
            Self.buildFreeTierSections(
                countryGroups: countryGroups,
                serverType: serverType,
                sections: &sections
            )
        } else {
            Self.buildPaidTierSections(
                countryGroups: countryGroups,
                serverType: serverType,
                sections: &sections
            )
        }

        return IdentifiedArray(uniqueElements: sections)
    }

    private static func buildFreeTierSections(
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

    private static func buildPaidTierSections(
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
                title: Localizable.locationsAll(countryRows.count),
                rows: IdentifiedArray(uniqueElements: countryRows),
                hasInfoButton: false,
                serversFilter: .default
            )
        )
    }
}
