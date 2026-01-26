//
//  Created on 23/12/2025 by Max Kupetskyi.
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
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

struct CountriesView: View {
    @Bindable var store: StoreOf<CountriesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            contentView
                .sheet(item: $store.scope(state: \.destination?.serversFeaturesInfo, action: \.destination.serversFeaturesInfo)) { store in
                    ServersFeaturesInformationView(store: store)
                        .padding()
                }
                .sheet(
                    item: $store
                        .scope(
                            state: \.destination?.serversStreamingFeaturesInfo,
                            action: \.destination.serversStreamingFeaturesInfo
                        )
                ) { store in
                    ServersStreamingFeaturesView(store: store)
                        .padding()
                }
                .sheet(item: $store.scope(state: \.destination?.discourageSecureCoreView, action: \.destination.discourageSecureCoreView)) { store in
                    DiscourageSecureCoreView(store: store)
                }
                .alert($store.scope(state: \.alert, action: \.alert))
        } destination: { store in
            switch store.case {
            case .search:
                Text("showing search")
            // TODO: VPNAPPL-3308
//                SearchViewWrapper(
//                    secureCoreOn: secureCoreOn,
//                    userTier: "free",
//                    searchData: [],
//                    navigationPath: $navigationPath
//                )
//                .navigationTitle(Localizable.searchTitle)
            case let .country(store):
                CountryView(store: store)
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: .themeSpacing0) {
            secureCoreBar
            Divider()
                .background(Color(uiColor: .normalSeparatorColor()))
            CountriesListView(store: store)
        }
        .background(Color(.background))
        .navigationTitle(Localizable.countries)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.background), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarContent }
    }

    private var secureCoreBar: some View {
        HStack {
            Text(Localizable.useSecureCore)
                .foregroundColor(Color(.text))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: Binding(
                get: { store.isSecureCore },
                set: { _ in store.send(.secureCoreToggleRequested) }
            )) {
                Text("")
            }
            .tint(Color(uiColor: .brandColor()))
            .disabled(!store.enableViewToggle)
            .accessibilityIdentifier("secureCoreSwitch")
        }
        .padding(.horizontal, .themeSpacing16)
        .frame(height: Dimensions.secureCoreBarHeight)
        .background(Color(.background))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                store.send(.showFeaturesInfo)
            }) {
                Image(uiImage: IconProvider.infoCircle)
                    .foregroundColor(.white)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                print("Search button tapped")
                store.send(.showSearch)
            }) {
                Image(uiImage: IconProvider.magnifier)
                    .foregroundColor(.white)
            }
            .accessibilityIdentifier("countrySearchButton")
        }
    }

    private enum Dimensions {
        static let secureCoreBarHeight: CGFloat = 50
    }
}
