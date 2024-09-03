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

public struct AppView: View {
    @Binding var store: StoreOf<AppFeature>

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.locale) var locale

    init(store: StoreOf<AppFeature>) {
        self._store = .constant(store)
    }

    public init() {
        self._store = .constant(.init(initialState: AppFeature.State(), reducer: { AppFeature() }))
    }

    public var body: some View {
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
        switch store.networking {
        case .unauthenticated, .acquiringSession:
            progressView
        case .authenticated(.auth):
            if let tier = store.userTier {
                if tier > 0 {
                    MainView(store: store.scope(state: \.main, action: \.main))
                        .background(Color(.background, .strong))
                        .onAppear {
                            store.send(.main(.onAppear))
                        }
                } else {
                    UpsellView(store: store.scope(state: \.upsell, action: \.upsell))
                        .background(Image(.backgroundStage))
                        .task { store.send(.upsell(.loadProducts))}
                }
            } else {
                progressView
            }
        case .authenticated(.unauth):
            WelcomeView(store: store.scope(state: \.welcome, action: \.welcome))
        }
    }

    private var progressView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.background, .strong))
    }
}
