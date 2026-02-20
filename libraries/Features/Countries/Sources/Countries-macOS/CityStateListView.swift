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

public struct CityStateListView: View {
    @Bindable var store: StoreOf<CityStateListFeature>

    public init(store: StoreOf<CityStateListFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Button {
                    if case .gateways = store.listType {
                        store.send(.navigateToServers(store.groupInfo))
                    } else {
                        store.send(.expand)
                    }
                } label: {
                    HStack {
                        Spacer()
                        IconProvider.chevronDownFilled.swiftUIImage
                            .resizable()
                            .rotationEffect(store.isExpanded ? .degrees(-180) : .degrees(0))
                            .foregroundColor(store.isExpanded ? Color(.icon) : Color(.icon, .weak))
                            .frame(.square(.themeSpacing20))
                    }
                    .padding(.themeSpacing12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.ghost)

                ConnectOnClickButton(action: { store.send(.connectToCountry) },
                                     groupInfo: store.groupInfo)
            }
            .popover(item: $store.scope(state: \.serversList, action: \.serversList), attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) { store in
                ServersListView(store: store)
            }

            if store.isExpanded {
                switch store.listType {
                case let .cities(groups), let .states(groups):
                    list(groups)
                case .gateways:
                    EmptyView() // remove
                }
            }
        }
        .background(store.isExpanded ? Color(.background, .transparent) : .clear)
        .clipRectangle(cornerRadius: .radius8)
        .padding(.trailing, .themeSpacing6)
    }

    private func list(_ groups: [ServerGroupInfo]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(groups, id: \.serverOfferingID) { groupInfo in
                ZStack {
                    expandButton(groupInfo)
                    ConnectOnClickButton(action: { store.send(.connectTo(groupInfo)) }, groupInfo: groupInfo)
                }
            }
        }
    }

    private func expandButton(_ groupInfo: ServerGroupInfo) -> some View {
        Button {
            store.send(.navigateToServers(groupInfo))
        } label: {
            HStack {
                Spacer()
                IconProvider.threeDotsVertical.swiftUIImage
                    .resizable()
                    .foregroundColor(Color(.icon, .weak))
                    .frame(.square(.themeSpacing20))
            }
            .padding(.themeSpacing12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ghost)
//        .padding(.trailing, .themeSpacing6)
    }
}

//#Preview {
//    let groups = [MockServerGroup.warsaw, MockServerGroup.malmo]
//    let state = CityStateListFeature.State(listState: .loaded(.cities(groups)), countryCode: "PL", groupInfo: MockServerGroup.warsaw)
//    CityStateListView(store: .init(initialState: state,
//                                   reducer: EmptyReducer.init))
//    .background(Color(.background, .weak))
//    .preferredColorScheme(.dark)
//}

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
            switch groupInfo.kind {
            case .country, .gateway:
                CountryToolbarItemView(groupInfo: groupInfo)
                    .font(.title3(emphasised: false))
            case .city, .state:
                HStack(spacing: .themeSpacing12) {
                    IconProvider.mapPin.swiftUIImage
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(Color(.icon, isDisabled ? .disabled : .weak))
                        .frame(.square(.themeSpacing20))
                        .padding(.horizontal, .themeSpacing4)
                    Text(groupInfo.kind.name)
                        .themeFont(.title3(emphasised: false))
                        .lineLimit(1)
                        .foregroundStyle(Color(.text, isDisabled ? .disabled : .normal))
                }
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

private enum MockServerGroup {
    static var warsaw: ServerGroupInfo {
        .init(kind: .city(name: "Warsaw", code: "PL"), featureIntersection: .restricted, featureUnion: .restricted, minTier: .paidTier, maxTier: .paidTier, serverCount: 2, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: false, isUnderMaintenance: false, protocolSupport: .wireGuardUDP)
    }

    static var malmo: ServerGroupInfo {
        .init(kind: .city(name: "Malmo", code: "SE"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: [.wireGuardTCP, .wireGuardUDP, .wireGuardTLS])
    }

    static var zurich: ServerGroupInfo {
        .init(kind: .city(name: "Zurich", code: "CH"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: .ikev2)
    }
}
