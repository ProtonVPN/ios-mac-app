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
import SwiftUI
import Theme

struct CountryView: View {
    @Bindable var store: StoreOf<CountryFeature>

    var body: some View {
        contentList
            .task {
                store.send(.onAppear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.background))
            .navigationTitle(store.countryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.background), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var contentList: some View {
        List {
            ForEach(store.scope(state: \.serverSections, action: \.serverSection)) { sectionStore in
                serverSection(for: sectionStore)
            }
        }
    }

    @ViewBuilder
    private func serverSection(
        for sectionStore: StoreOf<ServerSection>
    ) -> some View {
        Section {
            ForEach(sectionStore.scope(state: \.servers, action: \.servers)) { serverStore in
                serverRow(for: serverStore)
            }
        } header: {
            serverHeader(for: sectionStore.title)
        }
    }

    private func serverRow(
        for serverStore: StoreOf<ServerItemFeature>
    ) -> some View {
        ServerRow(
            store: serverStore,
            searchText: nil
        )
        .listRowInsets(.zero)
        .listRowSeparator(.hidden)
        .listRowBackground(Color(.background))
    }

    private func serverHeader(for title: String) -> some View {
        HStack {
            Text(title)
                .themeFont(.body2(emphasised: true))
                .foregroundColor(Color(.text, .weak))

            Spacer()
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
        .frame(height: Dimensions.countriesHeaderHeight)
    }

    enum Dimensions {
        static let countriesHeaderHeight: CGFloat = 40
    }
}
