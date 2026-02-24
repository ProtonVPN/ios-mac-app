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

import ComposableArchitecture
import ProtonCoreUIFoundations
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Dependency(\.appInfo) private var appInfo

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(spacing: .themeSpacing24) {
                    Spacer()
                    // TODO: We might bring this back
                    //                SettingsCellView(title: "Support Center", icon: IconProvider.lifeRing) {
                    //                    store.send(.showDrillDown(.supportCenter))
                    //                }
                    SettingsCellView(title: "Contact us", icon: IconProvider.speechBubble) {
                        store.send(.showDrillDown(.contactUs))
                    }
                    SettingsCellView(title: "Privacy policy", icon: IconProvider.fileEmpty) {
                        store.send(.showDrillDown(.privacyPolicy))
                    }
                    SettingsCellView(title: "Terms of service", icon: IconProvider.fileEmpty) {
                        store.send(.showDrillDown(.eula))
                    }
                    SettingsCellView(title: "Logs", icon: IconProvider.fileEmpty) {
                        store.send(.showLogs)
                    }
                    SettingsCellView(title: "Report an issue", icon: IconProvider.fileEmpty) {
                        store.send(.showReportIssue)
                    }
                    SettingsCellView(title: "Sign out", icon: IconProvider.arrowOutFromRectangle) {
                        store.send(.signOutSelected)
                    }
                    Spacer()
                    VStack(spacing: .themeSpacing8) {
                        if let userName = store.userDisplayName {
                            Text(verbatim: "\(userName)")
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(verbatim: appInfo.revisionInfo)
                            .font(.caption)
                            .foregroundStyle(Color(.text, .weak))
                    }
                }
            }
        } destination: { store in
            switch store.case {
            case let .settingsDrillDown(store):
                SettingsDrillDownView(store: store)
            case let .logSelection(store):
                LogSelectionView(store: store)
            case let .logs(store):
                LogsView(store: store)
            case let .reportIssue(store):
                ReportIssueView(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(
            isPresented: .init(get: { store.isLoading }, set: { _ in }),
            onDismiss: { store.send(.showProgressView) },
            content: {
                ProgressView("Signing out...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
            }
        )
    }
}

#if DEBUG
    #Preview {
        SettingsView(
            store: Store(initialState: .init()) {
                SettingsFeature()
            }
        )
    }
#endif
