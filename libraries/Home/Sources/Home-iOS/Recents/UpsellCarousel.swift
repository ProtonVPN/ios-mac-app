//
//  Created on 28/11/2024.
//
//  Copyright (c) 2024 Proton AG
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

import HomeShared
import Strings
import SwiftUI
import Theme

struct UpsellCarousel: View {
    @State private var scrollViewWidth: CGFloat = .zero
    let sendAction: RecentsFeature.ActionSender

    private var contentMargins: CGFloat {
        max((scrollViewWidth - Constants.maxHomeContentWidth) / 2, 0)
    }

    private var bannerWidth: CGFloat {
        let margins: CGFloat = .themeSpacing32
        let peek: CGFloat = .themeSpacing48
        return (scrollViewWidth - margins - peek) / 2
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(BannerType.allCases, id: \.hashValue) { type in
                    Button {
                        sendAction(.upsellTapped(type))
                    } label: {
                        UpsellBanner(type, width: bannerWidth)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .withMarginsForIPad(margins: contentMargins)
        .padding(.vertical, .themeSpacing8)
        .padding(.horizontal, .themeSpacing16)
        .overlay { GeometryReader { Color.clear.preference(key: CarouselWidthPreferenceKey.self, value: $0.size.width) } }
        .onPreferenceChange(CarouselWidthPreferenceKey.self) { scrollViewWidth = $0 }
    }
}

extension View {
    @ViewBuilder
    func withMarginsForIPad(margins: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            self
                .contentMargins(.horizontal, margins, for: .scrollContent)
                .scrollClipDisabled()
        } else {
            self
        }
    }
}

private struct UpsellBanner: View {
    let model: BannerModel
    let width: CGFloat

    init(_ type: BannerType, width: CGFloat) {
        self.model = BannerModel(type: type)
        self.width = max(126, min(300, width))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            model.image
                .swiftUIImage
            Text(model.title)
                .themeFont(.body2(emphasised: true))
            Text(model.subtitle)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .padding(.vertical, .themeSpacing24)
        .padding(.horizontal, .themeSpacing16)
        .frame(width: width)
        .background(Color(.background, .weak))
        .clipRectangle(cornerRadius: .radius8)
    }
}

private struct BannerModel {
    let title: String
    let subtitle: String
    let image: HomeShared.ImageAsset

    init(type: BannerType) {
        switch type {
        case .worldwideCover:
            self.title = Localizable.upsellCarouselWorldwideTitle
            self.subtitle = Localizable.upsellCarouselWorldwideSubtitle
            self.image = HomeAsset.worldwideCoverageSmall
        case .fasterBrowsing:
            self.title = Localizable.upsellCarouselFasterBrowsingTitle
            self.subtitle = Localizable.upsellCarouselFasterBrowsingSubtitle
            self.image = HomeAsset.speedSmall
        case .streaming:
            self.title = Localizable.upsellCarouselStreamingTitle
            self.subtitle = Localizable.upsellCarouselStreamingSubtitle
            self.image = HomeAsset.streamingMobileSmall
        case .netshield:
            self.title = Localizable.upsellCarouselNetshieldTitle
            self.subtitle = Localizable.upsellCarouselNetshieldSubtitle
            self.image = HomeAsset.netshieldMobileSmall
        case .secureCore:
            self.title = Localizable.upsellCarouselSecureCoreTitle
            self.subtitle = Localizable.upsellCarouselSecureCoreSubtitle
            self.image = HomeAsset.secureCoreSmall
        case .p2p:
            self.title = Localizable.upsellCarouselP2pTitle
            self.subtitle = Localizable.upsellCarouselP2pSubtitle
            self.image = HomeAsset.p2pSmall
        case .devices:
            self.title = Localizable.upsellCarouselDevicesTitle
            self.subtitle = Localizable.upsellCarouselDevicesSubtitle
            self.image = HomeAsset.multipleDevicesSmall
        case .tor:
            self.title = Localizable.upsellCarouselTorTitle
            self.subtitle = Localizable.upsellCarouselTorSubtitle
            self.image = HomeAsset.torSmall
        case .more:
            self.title = Localizable.upsellCarouselMoreTitle
            self.subtitle = Localizable.upsellCarouselMoreSubtitle
            self.image = HomeAsset.customisationMobileSmall
        }
    }
}

private struct CarouselWidthPreferenceKey: ViewDimensionPreferenceKey {}

#Preview {
    UpsellCarousel { _ in }
}
