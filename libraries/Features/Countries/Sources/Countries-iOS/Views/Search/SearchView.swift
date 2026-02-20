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

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    var body: some View {
        contentView
            .searchable(
                text: $store.searchQuery.sending(\.searchQueryChanged),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Localizable.searchBarPlaceholder
            )
            .task(id: store.searchQuery) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    await store.send(.searchQueryChangeDebounced).finish()
                } catch {}
            }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            let searchResultsStore = store.scope(state: \.searchResults, action: \.searchResults)
            switch searchResultsStore.state {
            case .placeholder:
                PlaceholderContentView(onlyCountries: store.mode == .secureCore)
            case .noResults:
                NoResultsContentView()
            case .recentSearches:
                if let store = searchResultsStore.scope(state: \.recentSearches, action: \.recentSearches) {
                    RecentSearchView(store: store)
                }
            case .resultsDisplay:
                if let store = searchResultsStore.scope(state: \.resultsDisplay, action: \.resultsDisplay) {
                    SearchResultsView(store: store)
                }
            }
        }
        .background(Color(.background))
    }
}
