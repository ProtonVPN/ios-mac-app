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
import Theme
import Strings

struct TelemetryCellView: View {

    let title: String
    let description: String

    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .themeFont(.body1())
                    .foregroundColor(Color(.text))
                    .padding(.bottom, .themeSpacing4)
                Text(description)
                    .themeFont(.caption())
                    .fixedSize(horizontal: false, vertical: true) // fixes a problem where this text would get truncated on smaller devices
                    .foregroundColor(Color(.text, .weak))
            }
            .layoutPriority(1) // This VStack should take as much space as it can

            Toggle(isOn: $isOn, label: { })
                .toggleStyle(SwitchToggleStyle(tint: Color(.icon, .interactive)))
        }
        .padding()
    }
}

struct TelemetryCellView_Previews: PreviewProvider {
    static var isOn = true
    static var previews: some View {
        TelemetryCellView(title: Localizable.onboardingUsageStatsTitle,
                          description: Localizable.onboardingUsageStatsDescription,
                          isOn: .init(get: {
            isOn
        }, set: { newValue in
            isOn = newValue
        }))
        .previewLayout(.sizeThatFits)
        .background(Color(.background))
    }
}
