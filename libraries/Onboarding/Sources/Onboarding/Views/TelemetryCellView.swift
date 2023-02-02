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

struct TelemetryCellView: View {

    let title: String
    let description: String

    @State var isOn: Bool
    var preferenceChange: (Bool) -> Void
    
    var colors: Colors = {
        Onboarding.colors
    }()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(colors.text.suColor)
                    .padding(.bottom, -4)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(colors.weakText.suColor)
            }
            .layoutPriority(1)

            Toggle(isOn: $isOn, label: { })
                .toggleStyle(SwitchToggleStyle(tint: colors.brand.suColor))
                .onChange(of: isOn, perform: preferenceChange) // Update the state of this preference
        }
        .padding()
    }
}

struct TelemetryCellView_Previews: PreviewProvider {
    static var previews: some View {
        TelemetryCellView(title: LocalizedString.onboardingUsageStatsTitle,
                          description: LocalizedString.onboardingUsageStatsDescription,
                          isOn: true,
                          preferenceChange: { _ in },
                          colors: previewColors)
        .previewLayout(.sizeThatFits)
        .background(previewColors.secondaryBackground.suColor)
    }
}
