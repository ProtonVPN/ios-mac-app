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

import ComposableArchitecture
import ConnectionInventory
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreUIFoundations
import SharedViews
import Sharing
import Strings
import SwiftUI
import Theme
import VPNAppCore

struct CityStateListView: View {
    @Bindable var store: StoreOf<CityStateListFeature>

    enum Dimensions: CGFloat {
        case popupSize = 350
        case popupBackgroundWorkaroundPadding = -15 // This is added so that the arrow of the popup also has the proper background
    }

    var body: some View {
        Group {
            switch store.listState {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { store.send(.didAppear) }
            case let .loaded(.cities(groups)),
                 let .loaded(.states(groups)):
                NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                    VStack(spacing: 0) {
                        header
                        list(groups)
                    }
                } destination: { store in
                    switch store.case {
                    case let .serversList(store):
                        ServersListView(store: store)
                    }
                }
            }
        }
        .padding(.themeSpacing8)
        .background(
            Color(.background, .weak)
                .padding(Dimensions.popupBackgroundWorkaroundPadding.rawValue)
        )
        .frame(.square(Dimensions.popupSize.rawValue))
    }

    private var header: some View {
        VStack(spacing: .themeSpacing16) {
            HStack(spacing: 0) {
                CountryToolbarItemView(countryCode: store.countryCode)
                    .font(.title2(emphasised: false))
                Spacer(minLength: 0)
            }
            if let title = store.sectionTitle {
                HStack(spacing: 0) {
                    Text(title)
                        .font(.themeFont(.body(emphasised: false)))
                        .foregroundColor(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
        }
        .padding([.horizontal, .top], .themeSpacing12)
        .padding(.bottom, .themeSpacing4)
    }

    private func list(_ groups: [ServerGroupInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groups, id: \.serverOfferingID) { groupInfo in
                    ZStack {
                        expandButton(groupInfo)
                        ConnectOnClickButton(action: { store.send(.connectTo(groupInfo)) }, groupInfo: groupInfo)
                    }
                }
            }
        }
    }

    private func expandButton(_ groupInfo: ServerGroupInfo) -> some View {
        Button {
            store.send(.navigateToCity(groupInfo))
        } label: {
            HStack {
                Spacer()
                IconProvider.threeDotsVertical.swiftUIImage
                    .resizable()
                    .foregroundColor(Color(.icon, .hint))
                    .frame(.square(.themeSpacing20))
            }
            .padding(.themeSpacing12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ghost)
        .padding(.trailing, .themeSpacing6)
    }
}

struct ConnectOnClickButton: View {
    let action: () -> Void
    let groupInfo: ServerGroupInfo
    @State var isHovering: Bool = false

    var body: some View {
        Button(action: action, label: label)
            .onHover { isHovering = $0 }
            .buttonStyle(.ghost)
            .padding(.trailing, .themeSpacing48) // a lot of padding to leave space for the three vertical dots
    }

    @SharedReader(.userTier) var userTier
    private func label() -> some View {
        HStack {
            HStack {
                IconProvider.mapPin.swiftUIImage
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(Color(.icon, isDisabled ? .disabled : .weak))
                    .frame(.square(.themeSpacing20))
                Text(groupInfo.kind.name)
                    .themeFont(.title3(emphasised: false))
                    .lineLimit(1)
                    .foregroundStyle(Color(.text, isDisabled ? .disabled : .normal))
            }
            Spacer(minLength: 0)
            if userTier?.isFreeTier == true {
                Theme.Asset.vpnSubscriptionBadge.swiftUIImage.resizable()
                    .scaledToFit()
                    .frame(height: .themeSpacing20)
            } else if groupInfo.isUnderMaintenance {
                IconProvider.wrench.swiftUIImage.resizable()
                    .frame(.square(.themeSpacing20))
                    .foregroundColor(Color(.icon, .normal))
            } else if isHovering {
                Text(Localizable.connect)
                    .themeFont(.body(emphasised: true))
            } else {
                CityStateServerFeaturesView(groupInfo: groupInfo)
                    .foregroundStyle(Color(.icon, .weak))
            }
        }
        .padding(.themeSpacing12)
        .contentShape(Rectangle())
        .help(help)
    }

    var isDisabled: Bool {
        groupInfo.isUnderMaintenance || userTier?.isFreeTier == true
    }

    var help: String {
        guard userTier?.isFreeTier != true else {
            return Localizable.upgradeToPlus
        }

        guard groupInfo.isUnderMaintenance else {
            return ""
        }
        switch groupInfo.kind {
        case .city:
            return Localizable.allServersInCityUnderMaintenance
        case .state:
            return Localizable.allServersInStateUnderMaintenance
        case .country:
            return Localizable.allServersInCountryUnderMaintenance
        case .gateway:
            return Localizable.allServersInGatewayUnderMaintenance
        }
    }
}
