//
//  Created on 2025-12-23 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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
import Dependencies
import Domain
import LegacyCommon
import Modals
import Payments
import SharedViews
import Sharing
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct CountriesListView: View {
    @Bindable var store: StoreOf<CountriesListFeature>

    public init(store: StoreOf<CountriesListFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.listState {
            case .loaded:
                if #available(macOS 15.0, *) {
                    scrollView
                        .scrollPosition($store.scrollPosition)
                } else {
                    scrollView
                }
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.themeSpacing8)
        .sheets(store: $store)
    }

    var scrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if !store.gateways.isEmpty {
                    gatewaysSection
                }
                if store.isFreeTier {
                    fastestConnectionSection
                }
                countriesSection
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var countriesSection: some View {
        Section {
            if store.isFreeTier {
                if let offer = store.offerBannerViewModel {
                    OfferBannerView(viewModel: offer, onDismiss: {
                        store.send(.loadOfferBanner)
                    })
                    .padding(.horizontal, .themeSpacing12)
                } else {
                    upsellBanner
                        .padding(.horizontal, .themeSpacing12)
                }
            }
            ForEach(store.scope(state: \.countries, action: \.countries)) { store in
                CityStateListView(store: store)
                    .id(store.id)
            }
        } header: {
            sectionHeader(title: Localizable.locationsAll(store.countries.count), action: .infoButtonTappedCountries)
        }
    }

    private var upsellBanner: some View {
        switch store.serverChangeAvailability {
        case .available:
            UpsellBannerView(viewModel: .init(
                leftIcon: Modals.Asset.worldwideCoverage,
                text: Localizable.freeBannerText
            ) {
                store.send(.upsellBannerTapped)
            })
        case .unavailable:
            UpsellBannerView(viewModel: .init(
                leftIcon: Modals.Asset.wrongCountry,
                text: Localizable.wrongCountryBannerText
            ) {
                store.send(.upsellBannerTapped)
            })
        }
    }

    private var gatewaysSection: some View {
        Section {
            ForEach(store.scope(state: \.gateways, action: \.gateways)) { store in
                CityStateListView(store: store)
                    .id(store.id)
            }
        } header: {
            sectionHeader(title: Localizable.locationsGateways, action: .infoButtonTappedGateways)
        }
    }

    private var fastestConnectionSection: some View {
        Section {
            Button {
                store.send(.connectToFastest)
            } label: {
                HStack(spacing: .themeSpacing8) {
                    Theme.Asset.Icons.bolt.swiftUIImage.resizable().frame(.square(.themeSpacing20))
                    Text(Localizable.fastest)
                        .themeFont(.title3(emphasised: false))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, .themeSpacing12)
                .padding(.horizontal, .themeSpacing16)
            }
            .buttonStyle(.ghost)
        } header: {
            sectionHeader(title: Localizable.connectionsFreeWithCount(1), action: .infoButtonTappedFreeConnections)
        }
    }

    private func sectionHeader(title: String, action: CountriesListFeature.Action) -> some View {
        HStack {
            Text(title)
                .font(.body(emphasised: true))
            Spacer(minLength: 0)
            Button {
                store.send(action)
            } label: {
                Theme.Asset.Icons.infoCircleFilled
                    .swiftUIImage
                    .resizable()
                    .frame(.square(.themeSpacing16))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color(.text, .hint))
        .padding([.vertical, .leading], .themeSpacing12)
        .padding(.trailing, .themeSpacing20)
    }
}

private struct CountriesListSheetsModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesListFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(state: \.destination?.featuresInfo, action: \.destination.featuresInfo)) { store in
                ServersFeaturesInformationView(store: store)
                    .frame(
                        width: Dimensions.ServersFeaturesInformation.width,
                        height: featuresInfoHeight(for: store)
                    )
            }
            .sheet(item: $store.scope(state: \.destination?.freeConnectionsInfo, action: \.destination.freeConnectionsInfo)) { store in
                FreeConnectionsView(store: store)
                    .frame(width: Dimensions.FreeConnections.width, height: Dimensions.FreeConnections.height)
            }
            .sheet(item: $store.scope(state: \.destination?.allCountriesUpsell, action: \.destination.allCountriesUpsell)) { store in
                UpsellViewController(
                    modalType: store.modalType,
                    upgradeAction: { store.send(.upgradeTapped) },
                    continueAction: { store.send(.continueTapped) }
                )
                .frame(width: Dimensions.Upsell.width, height: Dimensions.Upsell.height)
                .background(Color(.background))
            }
    }

    private func featuresInfoHeight(for store: StoreOf<ServersFeaturesInformationFeature>) -> CGFloat {
        let featureCount = store.sections.reduce(0) { $0 + $1.features.count }
        let sectionHeaderCount = store.sections.reduce(0) { partialResult, section in
            guard let title = section.title, store.showTitles, title != store.screenTitle else {
                return partialResult
            }
            return partialResult + 1
        }

        let estimatedHeight =
            Dimensions.ServersFeaturesInformation.topHeaderHeight +
            CGFloat.themeSpacing8 +
            CGFloat(featureCount) * Dimensions.ServersFeaturesInformation.estimatedFeatureRowHeight +
            CGFloat(sectionHeaderCount) * Dimensions.ServersFeaturesInformation.sectionHeaderHeight

        return min(Dimensions.ServersFeaturesInformation.maxHeight, estimatedHeight)
    }

    private enum Dimensions {
        enum ServersFeaturesInformation {
            static let width: CGFloat = 300
            static let maxHeight: CGFloat = 500
            static let topHeaderHeight: CGFloat = 44
            static let sectionHeaderHeight: CGFloat = 52
            static let estimatedFeatureRowHeight: CGFloat = 108
        }

        enum FreeConnections {
            static let width: CGFloat = 520
            static let height: CGFloat = 500
        }

        enum Upsell {
            static let width: CGFloat = 520
            static let height: CGFloat = 590
        }
    }
}

private extension View {
    func sheets(store: Bindable<StoreOf<CountriesListFeature>>) -> some View {
        modifier(CountriesListSheetsModifier(store: store.wrappedValue))
    }
}

#if DEBUG
    private enum MockServerGroup {
        static var warsaw: ServerGroupInfo {
            .init(kind: .country(code: "PL"), featureIntersection: .restricted, featureUnion: .restricted, minTier: .paidTier, maxTier: .paidTier, serverCount: 2, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: false, isUnderMaintenance: false, protocolSupport: .wireGuardUDP)
        }

        static var malmo: ServerGroupInfo {
            .init(kind: .country(code: "SE"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: [.wireGuardTCP, .wireGuardUDP, .wireGuardTLS])
        }

        static var zurich: ServerGroupInfo {
            .init(kind: .country(code: "CH"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: .ikev2)
        }
    }
#endif
