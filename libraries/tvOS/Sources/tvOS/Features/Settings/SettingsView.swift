//
//  Created on 23/04/2024.
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
import ProtonCoreUIFoundations

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: .themeSpacing24) {
                Spacer()
                SettingsCellView(title: "Support Center", icon: IconProvider.lifeRing) {
                    store.send(.showDrillDown(.supportCenter))
                }
                SettingsCellView(title: "Contact us", icon: IconProvider.speechBubble) {
                    store.send(.showDrillDown(.contactUs))
                }
                SettingsCellView(title: "Privacy policy", icon: IconProvider.fileEmpty) {
                    store.send(.showDrillDown(.privacyPolicy))
                }
                SettingsCellView(title: "Sign out", icon: IconProvider.arrowOutFromRectangle) {
                    store.send(.signOutSelected)
                }
                Spacer()
                if let userName = store.userDisplayName {
                    Text(verbatim: "\(userName)")
                }
                Text(verbatim: Bundle.appVersion)
                    .font(.caption)
                    .foregroundStyle(Color(.text, .weak))
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(isPresented: .init(get: { store.isLoading }, set: { _ in }),
                         onDismiss: { store.send(.showProgressView) },
                         content: {
            ProgressView("Signing out...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
        })
        .navigationDestination(item: $store.scope(state: \.destination?.settingsDrillDown,
                                                  action: \.destination.settingsDrillDown)) { store in
            SettingsDrillDownView(store: store)
        }
    }
}
