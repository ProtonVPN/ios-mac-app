//
//  Created on 28/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import CountriesShared
import Strings
import SwiftUI

struct RecentSearchView: View {
    @Bindable var store: StoreOf<SearchRecentsFeature>

    var body: some View {
        List {
            Section {
                ForEach(store.recentSearches, id: \.self) { search in
                    Button(action: {
                        store.send(.recentTapped(search))
                    }) {
                        HStack {
                            Image("ic-history-back", bundle: CountriesResources.bundle)
                                .foregroundStyle(Color(.background, .interactive))
                                .frame(.square(24))

                            Text(search)
                                .foregroundColor(Color(.text))

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Color(.background))
                    .listRowSeparator(.visible)
                }
            } header: {
                header
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    var header: some View {
        HStack {
            Text("\(Localizable.searchRecentHeader) (\(store.recentSearches.count))")
                .themeFont(.caption())
                .foregroundColor(Color(.text, .weak))

            Spacer()

            if !store.recentSearches.isEmpty {
                Button(action: {
                    store.send(.clear)
                }) {
                    Text(Localizable.searchRecentClear)
                        .themeFont(.caption())
                        .foregroundColor(Color(.background, .interactive))
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .background(Color(.background))
    }
}
