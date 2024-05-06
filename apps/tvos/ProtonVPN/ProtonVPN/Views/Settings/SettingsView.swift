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
    
    let appVersion: String = {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "v\(appVersion) (\(bundleVersion))"
        }
        return "v0.0.0 (0)"
    }()

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()
            SettingsCellView(title: "Contact us", icon: IconProvider.speechBubble) {
                store.send(.contactUs)
            }
            SettingsCellView(title: "Report an issue", icon: IconProvider.exclamationCircle) {
                store.send(.reportAnIssue)
            }
            SettingsCellView(title: "Privacy policy", icon: IconProvider.file) {
                store.send(.privacyPolicy)
            }
            SettingsCellView(title: "Sign out", icon: IconProvider.arrowOutFromRectangle) {
                store.send(.signOutSelected)
            }
            Spacer()
            if let userName = store.userName {
                Text("user: \(userName)")
            }
            Text(appVersion)
        }
        .frame(maxWidth: 800)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

struct SettingsCellView: View {

    let title: String
    let icon: Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .themeSpacing32) {
                icon
                    .resizable()
                    .frame(.square(48))
                Text(title)
                    .font(.callout)
                Spacer()
            }
            .frame(height: 120)
        }
    }
}
