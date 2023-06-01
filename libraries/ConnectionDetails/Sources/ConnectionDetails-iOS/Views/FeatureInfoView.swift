//
//  Created on 2023-06-06.
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
import VPNShared
import Strings

struct FeatureInfoView: View {

    let icon: ImageAsset
    let title: String
    let text: String

    @ScaledMetric var infoIconSize: CGFloat = 16
    @ScaledMetric var mainIconSize: CGFloat = 20

    var body: some View {
        HStack(alignment: .top) {
            icon.swiftUIImage
                .resizable().frame(width: mainIconSize, height: mainIconSize)
                .foregroundColor(Color(.text, .normal))

            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.themeFont(.body2(emphasised: true)))
                        .foregroundColor(Color(.text, .normal))

                    Spacer()

                    Text(Localizable.connectionDetailsInfoButton)
                        .font(.themeFont(.caption(emphasised: true)))
                        .foregroundColor(Color(.text, .weak))

                    Asset.icInfoCircle.swiftUIImage
                        .resizable().frame(width: infoIconSize, height: infoIconSize)
                        .foregroundColor(Color(.text, .weak))
                }

                Text(text)
                    .multilineTextAlignment(.leading)
                    .font(.themeFont(.caption()))
                    .foregroundColor(Color(.text, .weak))
                    .padding(0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.themeSpacing16)
        .background(RoundedRectangle(cornerRadius: .themeRadius12)
            .fill(Color(.background, [.normal])))
    }
}

extension FeatureInfoView {
    init(for feature: ConnectionSpec.Feature) {
        switch feature {
        case .tor:
            icon = Asset.icBrandTor
            title = Localizable.connectionDetailsFeatureTitleTor
            text = Localizable.connectionDetailsFeatureDescriptionTor

        case .p2p:
            icon = Asset.icArrowRightArrowLeft
            title = Localizable.connectionDetailsFeatureTitleP2p
            text = Localizable.connectionDetailsFeatureDescriptionP2p

        case .smart:
            icon = Asset.icGlobe
            title = Localizable.connectionDetailsFeatureTitleSmartRouting
            text = Localizable.connectionDetailsFeatureDescriptionSmartRouting

        case .streaming:
            icon = Asset.icArrowRightArrowLeft
            title = Localizable.connectionDetailsFeatureTitleStreaming
            text = Localizable.connectionDetailsFeatureDescriptionStreaming

        case .partner:
            icon = Asset.icQuestionCircle
            title = "No such screen"
            text = "No such screen"
        }
    }

    init(secureCore: Bool) {
        icon = Asset.icLockLayers
        title = Localizable.connectionDetailsFeatureTitleSecureCore
        text = Localizable.connectionDetailsFeatureDescriptionSecureCore
    }

}

// MARK: - Previews

struct FeatureInfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeatureInfoView(secureCore: true).previewDisplayName("Secure Core")
            FeatureInfoView(for: .tor).previewDisplayName("Tor")
            FeatureInfoView(for: .p2p).previewDisplayName("P2P")
            FeatureInfoView(for: .smart).previewDisplayName("Smart Routing")
        }
    }
}
