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

struct SearchRootView: View {
    @Bindable var store: StoreOf<SearchRoot>

    var body: some View {
        Group {
            switch store.state {
            case .loading:
                loadingView

            case .loaded:
                if let store = store.scope(state: \.loaded, action: \.loaded) {
                    SearchView(store: store)
                }
            }
        }
        .navigationTitle(Localizable.searchTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.background), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(.text)))
                .scaleEffect(1.5)
        }
    }
}
