//
//  Created on 06/03/2026 by Max Kupetskyi.
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

import PaymentsShared
import SwiftUI
import Theme

struct LegacyPaymentsModalBodyView: View {
    let upsellModalType: UpsellModalType
    let imagePadding: EdgeInsets?
    let displayBodyFeatures: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Group {
                if let imagePadding {
                    upsellModalType.artImage()
                        .padding(imagePadding)
                } else {
                    upsellModalType.artImage()
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: .themeSpacing8) {
                Text(upsellModalType.title)
                    .themeFont(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle = upsellModalType.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .themeFont(.body1(.regular))
                        .foregroundColor(Color(.text, .weak))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, .themeSpacing16)

            if displayBodyFeatures {
                let features = upsellModalType.features()
                if !features.isEmpty {
                    Spacer().frame(height: .themeSpacing24)
                    LegacyUpsellFeaturesView(features: features)
                        .padding(.horizontal, .themeSpacing16)
                }
            }
        }
    }
}
