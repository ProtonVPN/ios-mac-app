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

struct TelemetryTogglesView: View {
    @Binding var usageStatisticsOn: Bool
    @Binding var crashReportsOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TelemetryCellView(
                    title: LocalizedString.onboardingUsageStatsTitle,
                    description: LocalizedString.onboardingUsageStatsDescription,
                    isOn: $usageStatisticsOn
                )
                Divider()
                    .background(Color(.border))
                    .padding(.leading)
                TelemetryCellView(
                    title: LocalizedString.onboardingCrashReportsTitle,
                    description: LocalizedString.onboardingCrashReportsDescription,
                    isOn: $crashReportsOn
                )
            }
            .background(Color(.background))
            OnboardingFooter()
        }
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
