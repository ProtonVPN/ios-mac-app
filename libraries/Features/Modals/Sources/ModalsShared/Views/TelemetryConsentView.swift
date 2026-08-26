//
//  Created on 26/08/2026 by Max Kupetskyi.
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
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Strings
import SwiftUI
import Theme

public struct TelemetryConsentView: View {
    @Bindable private var store: StoreOf<TelemetryConsentFeature>

    public init(store: StoreOf<TelemetryConsentFeature>) {
        self.store = store
    }

    public var body: some View {
        TelemetryConsentBody(
            sharesUsageData: $store.sharesUsageData,
            sharesCrashReports: $store.sharesCrashReports
        ) {
            store.send(.confirmButtonTapped)
        }
    }
}

#if os(macOS)

    private struct TelemetryConsentBody: View {
        @Binding var sharesUsageData: Bool
        @Binding var sharesCrashReports: Bool
        let confirm: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: .themeSpacing16) {
                Text(Localizable.usageStatistics)
                    .themeFont(.title3(emphasised: true))
                    .foregroundStyle(Color(.text))
                    .padding(.horizontal, TelemetryTogglesView.contentInset)

                TelemetryTogglesView(
                    sharesUsageData: $sharesUsageData,
                    sharesCrashReports: $sharesCrashReports
                )

                HStack {
                    Spacer()
                    Button(Localizable.done, action: confirm)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, TelemetryTogglesView.contentInset)
            }
            .padding(.vertical, .themeSpacing24)
            .frame(width: 420)
            .background(Color(.background, .weak))
        }
    }

#else

    private struct TelemetryConsentBody: View {
        @Binding var sharesUsageData: Bool
        @Binding var sharesCrashReports: Bool
        let confirm: () -> Void

        var body: some View {
            NavigationStack {
                TelemetryTogglesView(
                    sharesUsageData: $sharesUsageData,
                    sharesCrashReports: $sharesCrashReports
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.background, .weak))
                .navigationTitle(Localizable.usageStatistics)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Localizable.done, action: confirm)
                    }
                }
            }
        }
    }

#endif
