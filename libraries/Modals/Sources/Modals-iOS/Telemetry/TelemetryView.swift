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
import Strings

struct TelemetryView: View {

    @State var image = UIImage(named: "telemetry-illustration",
                               in: .module,
                               compatibleWith: nil)
    @State var usageStatisticsOn: Bool = true
    @State var crashReportsOn: Bool = true

    var completion: ((Bool, Bool) -> Void)

    var body: some View {
        ZStack {
            Color(.background, .strong).ignoresSafeArea()
            VStack() {
                Spacer()
                Image(uiImage: image!)
                Text(Localizable.onboardingTelemetryTitle)
                    .themeFont(.headline)
                    .foregroundColor(Color(.text))
                    .padding()

                TelemetryTogglesView(usageStatisticsOn: $usageStatisticsOn,
                                     crashReportsOn: $crashReportsOn)
                Spacer()
                Button {
                    completion(usageStatisticsOn, crashReportsOn)
                } label: {
                    Text(Localizable.modalsCommonNext)
                }
                .padding(.bottom)
            }
        }
    }
}

struct TelemetryView_Previews: PreviewProvider {
    static var previews: some View {
        TelemetryView() { _, _ in

        }
    }
}
