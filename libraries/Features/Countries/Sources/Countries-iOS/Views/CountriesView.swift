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
import Modals
import Payments
import Strings
import SwiftUI
import Theme

struct CountriesView: View {
    @Bindable var store: StoreOf<CountriesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            contentView
                .sheets(store: $store)
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
                .background(Color(.border))
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

private struct CountriesSheetsModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .modifier(CountriesSheetsSheetModifier(store: store))
            .modifier(CountriesSheetsFullScreenCoverModifier(store: store))
    }
}

private struct CountriesSheetsSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .modifier(CityStateListSheetModifier(store: store))
            .modifier(ServersFeaturesInfoSheetModifier(store: store))
            .modifier(ServersStreamingFeaturesSheetModifier(store: store))
            .modifier(DiscourageSecureCoreSheetModifier(store: store))
            .modifier(FreeConnectionsSheetModifier(store: store))
    }
}

private struct CityStateListSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(
                state: \.destination?.cityStateList,
                action: \.destination.cityStateList
            )) { store in
                CityStateListView(store: store)
                    .presentationDetents([.medium, .large])
                    .presentationContentInteraction(.scrolls)
            }
    }
}

private struct ServersFeaturesInfoSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(
                state: \.destination?.serversFeaturesInfo,
                action: \.destination.serversFeaturesInfo
            )) { store in
                ServersFeaturesInformationView(store: store)
            }
    }
}

private struct ServersStreamingFeaturesSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(
                state: \.destination?.serversStreamingFeaturesInfo,
                action: \.destination.serversStreamingFeaturesInfo
            )) { store in
                ServersStreamingFeaturesView(store: store)
            }
    }
}

private struct DiscourageSecureCoreSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(
                state: \.destination?.discourageSecureCoreView,
                action: \.destination.discourageSecureCoreView
            )) { store in
                DiscourageSecureCoreView(store: store)
            }
    }
}

private struct FreeConnectionsSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(
                state: \.destination?.freeConnectionsView,
                action: \.destination.freeConnectionsView
            )) { store in
                FreeConnectionsView(store: store)
            }
    }
}

private struct CountriesSheetsFullScreenCoverModifier: ViewModifier {
    @Bindable var store: StoreOf<CountriesFeature>

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $store.scope(state: \.destination?.payments, action: \.destination.payments)) { store in
                PaymentsMainView(store: store)
            }
    }
}

private extension View {
    func sheets(store: Bindable<StoreOf<CountriesFeature>>) -> some View {
        modifier(CountriesSheetsModifier(store: store.wrappedValue))
    }
}
