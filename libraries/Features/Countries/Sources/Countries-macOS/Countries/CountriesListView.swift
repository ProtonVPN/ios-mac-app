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
        .task { store.send(.didAppear) }
    }

    func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.body(emphasised: true))
            Spacer(minLength: 0)
            IconProvider.infoCircleFilled
                .swiftUIImage
                .resizable()
                .frame(.square(.themeSpacing16))
        }
        .foregroundStyle(Color(.text, .hint))
        .padding([.vertical, .leading], .themeSpacing12)
        .padding(.trailing, .themeSpacing20)
    }

    var scrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !store.gateways.isEmpty {
                    Section {
                        ForEach(store.scope(state: \.gateways, action: \.gateways)) { store in
                            CityStateListView(store: store)
                                .id(store.id)
                        }
                    } header: {
                        sectionHeader(title: "Gateways")
                    }
                }

                Section {
                    ForEach(store.scope(state: \.countries, action: \.countries)) { store in
                        CityStateListView(store: store)
                            .id(store.id)
                    }
                } header: {
                    sectionHeader(title: "All locations (\(store.countries.count))")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
//
//#Preview {
//    let groups = [MockServerGroup.malmo, MockServerGroup.warsaw, MockServerGroup.zurich]
//    if #available(macOS 15.0, *) {
//        let state = CountriesListFeature.State(groups: groups)
//        CountriesListView(store: .init(initialState: state, reducer: CountriesListFeature.init))
//            .preferredColorScheme(.dark)
//    }
//}

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
