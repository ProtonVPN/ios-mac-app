//
//  Created on 02/02/2023.
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

struct TelemetryView: View {

    @State var image = UIImage(named: "telemetry-illustration",
                               in: .module,
                               compatibleWith: nil)

    var preferenceChangeUsageData: ((Bool) -> Void)
    var preferenceCrashReports: ((Bool) -> Void)
    var usageStatisticsOn: Bool?
    var crashReportsOn: Bool?

    var completion: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.background, .strong).ignoresSafeArea()
                VStack() {
                    Spacer()
                    Image(uiImage: image!)
                    Text(LocalizedString.onboardingTelemetryTitle)
                        .themeFont(.headline)
                        .foregroundColor(Color(.text))
                        .padding()

                    TelemetryTogglesView(preferenceChangeUsageData: preferenceChangeUsageData,
                                         preferenceCrashReports: preferenceCrashReports,
                                         usageStatisticsOn: usageStatisticsOn,
                                         crashReportsOn: crashReportsOn)
                    OnboardingButton(completion: completion,
                                     geometry: geometry)
                }
            }
        }
    }
}

struct TelemetryView_Previews: PreviewProvider {
    static var previews: some View {
        TelemetryView(preferenceChangeUsageData: { _ in },
                      preferenceCrashReports: { _ in })
    }
}
