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
            VStack(spacing: 0) {
                // Secure Core Bar
                HStack {
                    Text(Localizable.useSecureCore)
                        .foregroundColor(Color(.text))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle(isOn: Binding(
                        get: { store.isSecureCore },
                        set: { _ in store.send(.secureCoreToggled) }
                    )) {
                        Text("")
                    }
                    .tint(Color(uiColor: .brandColor()))
                    .disabled(!store.enableViewToggle)
                    .accessibilityIdentifier("secureCoreSwitch")
                }
                .padding(.horizontal, .themeSpacing16)
                .frame(height: 50)
                .background(Color(.background))

                Divider()
                    .background(Color(uiColor: .normalSeparatorColor()))

                // Table Content
                CountriesListView(store: store)
            }
            .background(Color(.background))
            .navigationTitle(Localizable.countries)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.background), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
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
            // TODO: VPNAPPL-3313
//            .sheet(item: $store.scope(state: \.destination?.cityStateList, action: \.destination.cityStateList)) { store in
//                CityStateListView(store: store)
//                    .padding()
//            }
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
}
