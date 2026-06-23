//
//  Created on 22/06/2026 by Max Kupetskyi.
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
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import HomeShared
import Strings
import SwiftUI
import Theme

/// Map overlay shown at the top of the home screen while Advanced killswitch is on
struct KillSwitchBlockingBanner: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(.icon, .weak).opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: .themeSpacing8) {
                HomeAsset.advancedKs.swiftUIImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: Dimensions.iconHeight)
                    .accessibilityHidden(true)

                Text(Localizable.killSwitchAdvancedBannerTitle)
                    .font(.themeFont(.body1(.bold)))
                    .foregroundColor(Color(.text))

                Text(Localizable.killSwitchAdvancedBannerMessage)
                    .font(.themeFont(.body2()))
                    .foregroundColor(Color(.text, .weak))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, .themeSpacing16)
        }
        .frame(height: Dimensions.viewHeight)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private enum Dimensions {
        static let viewHeight: CGFloat = 200
        static let iconHeight: CGFloat = 24
    }
}
