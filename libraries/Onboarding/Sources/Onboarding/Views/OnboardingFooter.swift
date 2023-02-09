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

struct OnboardingFooter: View {

    private let urlUsageStatistics = "https://protonvpn.com/support/anonymous-usage-statistics"

    var colors: Colors = {
        Onboarding.colors
    }()

    var body: some View {
        // Find a way to combine the learn more text and the footer text into one localized string. We only have one localization that reads right-to-left at the moment, but there will probably be more in the future.
        (Text(LocalizedString.onboardingFooter + " ") + Text(LocalizedString.onboardingFooterLearnMore)
            .foregroundColor(colors.textAccent.suColor)
        )
        .padding()
        .background(colors.background.suColor)
        .foregroundColor(colors.weakText.suColor)
        .font(.system(size: 13))
        .onTapGesture {
            guard let url = URL(string: urlUsageStatistics),
                  UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }
    }
}

struct OnboardingFooter_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFooter(colors: previewColors)
            .previewLayout(.sizeThatFits)
    }
}
