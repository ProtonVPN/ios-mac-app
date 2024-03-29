//
//  Created on 03/02/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Strings
import Theme

struct TelemetryTogglesView: View {
    @Binding var usageStatisticsOn: Bool
    @Binding var crashReportsOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TelemetryCellView(
                    title: Localizable.onboardingUsageStatsTitle,
                    description: Localizable.onboardingUsageStatsDescription,
                    isOn: $usageStatisticsOn
                )
                Divider()
                    .background(Color(.border))
                    .padding(.leading)
                TelemetryCellView(
                    title: Localizable.onboardingCrashReportsTitle,
                    description: Localizable.onboardingCrashReportsDescription,
                    isOn: $crashReportsOn
                )
            }
            .background(Color(.background))
            OnboardingFooter()
        }
        .frame(maxWidth: Theme.Constants.readableContentWidth)
    }
}

struct TelemetryTogglesView_Previews: PreviewProvider {
    @State static var usageStatisticsOn: Bool = true
    @State static var crashReportsOn: Bool = true
    static var previews: some View {
        TelemetryTogglesView(usageStatisticsOn: $usageStatisticsOn,
                             crashReportsOn: $crashReportsOn)
            .previewLayout(.sizeThatFits)
    }
}

struct OnboardingFooter: View {

    private let urlUsageStatistics = URL(string: "https://protonvpn.com/support/share-usage-statistics")!

    var body: some View {
        Link(destination: urlUsageStatistics, label: {
            // Find a way to combine the learn more text and the footer text into one localized string. We only have one localization that reads right-to-left at the moment, but there will probably be more in the future.
            (Text(Localizable.onboardingFooter + " ") + Text(Localizable.onboardingFooterLearnMore)
                .foregroundColor(Color(.text, .interactive))
            )
            .themeFont(.caption())
            .padding()
            .foregroundColor(Color(.text, .weak))
        })
    }
}

struct OnboardingFooter_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFooter()
            .previewLayout(.sizeThatFits)
    }
}
