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

struct ModalFeaturesView: View {
    struct FeatureItem: Identifiable {
        let id = UUID()
        let feature: Feature
    }

    let featureItems: [FeatureItem]

    init(features: [Feature]) {
        self.featureItems = features.map(FeatureItem.init(feature:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            ForEach(featureItems) { featureItem in
                let feature = featureItem.feature

                HStack(spacing: .themeSpacing8) {
                    let green = feature == .moneyGuarantee
                    feature.image.swiftUIImage
                        .foregroundColor(Color(.icon, green ? .success : [.interactive, .active]))
                    if let title = try? AttributedString(markdown: feature.title()) {
                        Text(title)
                            .foregroundColor(Color(.text, green ? .success : []))
                    }
                }
            }
        }
        .padding(.vertical, .themeSpacing16)
        .padding(.horizontal, .themeSpacing24)
        .themeBorder(color: Color(.border),
                     lineWidth: 1,
                     cornerRadius: .radius12)
    }
}

struct ModalFeatures_Previews: PreviewProvider {
    static var previews: some View {
        ModalFeaturesView(features: [.accessLAN, .blockAds, .addLayer])
            .previewDisplayName("Modal Features")
    }
}
