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
    var colors: Colors = {
        Onboarding.colors
    }()

    var preferenceChangeUsageData: ((Bool) -> Void)
    var preferenceCrashReports: ((Bool) -> Void)
    var usageStatisticsOn: Bool?
    var crashReportsOn: Bool?

    var completion: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                colors.background.suColor.ignoresSafeArea()
                VStack() {
                    Spacer()
                    Image(uiImage: image!)
                    Text(LocalizedString.onboardingTelemetryTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(colors.text.suColor)
                        .padding()
                    
                    TelemetryTogglesView(colors: colors,
                                         preferenceChangeUsageData: preferenceChangeUsageData,
                                         preferenceCrashReports: preferenceCrashReports,
                                         usageStatisticsOn: usageStatisticsOn,
                                         crashReportsOn: crashReportsOn)
                    OnboardingButton(completion: completion,
                                     geometry: geometry,
                                     colors: colors)
                }
            }
        }
    }
}

struct TelemetryView_Previews: PreviewProvider {
    static var previews: some View {
        TelemetryView(colors: previewColors,
                      preferenceChangeUsageData: { _ in },
                      preferenceCrashReports: { _ in })
    }
}
