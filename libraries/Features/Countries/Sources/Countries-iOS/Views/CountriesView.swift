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
import CountriesShared
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
                }
                .sheet(
                    item: $store
                        .scope(
                            state: \.destination?.serversStreamingFeaturesInfo,
                            action: \.destination.serversStreamingFeaturesInfo
                        )
                ) { store in
                    ServersStreamingFeaturesView(store: store)
                }
                .sheet(item: $store.scope(state: \.destination?.discourageSecureCoreView, action: \.destination.discourageSecureCoreView)) { store in
                    DiscourageSecureCoreView(store: store)
                }
                .alert($store.scope(state: \.alert, action: \.alert))
        } destination: { store in
            switch store.case {
            case let .search(store):
                SearchRootView(store: store)
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
            .foregroundStyle(Color(.background, .interactive))
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
                Theme.Asset.Icons.infoCircle.swiftUIImage
                    .foregroundColor(.white)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                store.send(.showSearch)
            }) {
                Theme.Asset.Icons.magnifier.swiftUIImage
                    .foregroundColor(.white)
            }
            .accessibilityIdentifier("countrySearchButton")
        }
    }

    private enum Dimensions {
        static let secureCoreBarHeight: CGFloat = 50
    }
}
