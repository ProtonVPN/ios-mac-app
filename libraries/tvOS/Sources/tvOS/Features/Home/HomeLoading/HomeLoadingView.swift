//
//  Created on 09/06/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import ComposableArchitecture

struct HomeLoadingView: View {

    @Bindable var store: StoreOf<HomeLoadingFeature>

    var body: some View {
        switch store.state {
        case .loading:
            VStack(spacing: .themeSpacing24) {
                ProgressView()
                Text("Loading countries")
                    .font(Font.headline)
                    .foregroundStyle(Color(.text))
            }
            .onAppear {
                store.send(.loadingViewOnAppear)
            }
        case .loaded:
            if let store = store.scope(state: \.loaded, action: \.loaded) {
                HomeView(store: store)
            }
        case .loadingFailed:
            Text("There was a problem.\nPlease check your network connection")
                .font(Font.headline)
                .foregroundStyle(Color(.text))
                .multilineTextAlignment(.center)
        }
    }
}
