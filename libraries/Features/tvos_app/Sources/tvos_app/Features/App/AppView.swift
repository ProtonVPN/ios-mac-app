//
//  Created on 25/04/2024.
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

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Binding var store: StoreOf<AppFeature>

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.locale) var locale

    init(store: StoreOf<AppFeature>) {
        _store = .constant(store)
    }

    init() {
        _store = .constant(.init(initialState: AppFeature.State(), reducer: { AppFeature() }))
    }

    var body: some View {
        viewBody
            .alert($store.scope(state: \.alert, action: \.alert))
            .task {
                await store.send(.onAppearTask).finish()
            }
            .environment(\.layoutDirection, locale.isRTLLanguage ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    @MainActor
    private var viewBody: some View {
        let screenStore = store.scope(state: \.screen, action: \.screen)
        switch screenStore.case {
        case let .loading(loadingStore):
            LoadingView(store: loadingStore)
        case let .welcome(welcomeStore):
            WelcomeView(store: welcomeStore)
        case let .main(mainStore):
            MainView(store: mainStore)
                .background(Color(.background, .strong))
                .onAppear {
                    store.send(.screen(.main(.onAppear)))
                }
        }
    }
}
