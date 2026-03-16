//
//  Created on 21/01/2026 by Max Kupetskyi.
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
import SwiftUI
import Theme

/// Wrapper view that handles loading/loaded states from CountriesMainFeature
public struct CountriesMainView: View {
    @Bindable var store: StoreOf<CountriesMainFeature>

    public init(store: StoreOf<CountriesMainFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.state {
            case .loading:
                loadingView

            case .standard:
                if let store = store.scope(state: \.standard, action: \.standard) {
                    CountriesView(store: store)
                }

            case .secureCore:
                if let store = store.scope(state: \.secureCore, action: \.secureCore) {
                    CountriesView(store: store)
                }
            }
        }
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

#if DEBUG
    #Preview("Loading State") {
        CountriesMainView(
            store: Store(initialState: .loading) {
                CountriesMainFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Standard State") {
        CountriesMainView(
            store: Store(initialState: .standard(.init(sections: IdentifiedArrayOf<CountrySectionFeature.State>()))) {
                CountriesMainFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("SecureCore State") {
        CountriesMainView(
            store: Store(initialState: .secureCore(.init(sections: IdentifiedArrayOf<CountrySectionFeature.State>()))) {
                CountriesMainFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
