//
//  Created on 13/12/2023.
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
import Modals

struct ModalBodyView: View {

    let upsellType: UpsellType

    var body: some View {
        VerticallyCenteringScrollView {
            VStack(spacing: 0) {
                upsellType.artImage()

                VStack(spacing: .themeSpacing8) {
                    Text(upsellType.upsellFeature().title)
                        .themeFont(.headline)
                        .multilineTextAlignment(.center)
                    if let subtitle = upsellType.upsellFeature().subtitle,
                       let subtitle = try? AttributedString(markdown: subtitle,
                                                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(subtitle)
                            .themeFont(.body1(.regular))
                            .foregroundColor(Color(.text, .weak))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                Spacer().frame(height: .themeSpacing24)
                let features = upsellType.upsellFeature().features
                if features.contains(.banner) {
                    BannerView()
                } else if !features.isEmpty {
                    ModalFeaturesView(features: features)
                }
            }
        }
    }
}

struct ModalBody_Previews: PreviewProvider {
    static var previews: some View {
        ModalBodyView(upsellType: .welcomePlus(numberOfServers: 1800,
                                               numberOfDevices: 10,
                                               numberOfCountries: 68))
            .previewDisplayName("ModalBody")
    }
}
