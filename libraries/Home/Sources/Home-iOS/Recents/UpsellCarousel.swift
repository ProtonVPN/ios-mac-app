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

import SwiftUI
import HomeShared
import Strings
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

fileprivate struct UpsellBanner: View {

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

fileprivate struct BannerModel {
    let title: String
    let subtitle: String
    let image: HomeShared.ImageAsset

    init(type: BannerType) {
        switch type {
        case .worldwideCover:
            title = Localizable.upsellCarouselWorldwideTitle
            subtitle = Localizable.upsellCarouselWorldwideSubtitle
            image = HomeAsset.worldwideCoverageSmall
        case .fasterBrowsing:
            title = Localizable.upsellCarouselFasterBrowsingTitle
            subtitle = Localizable.upsellCarouselFasterBrowsingSubtitle
            image = HomeAsset.speedSmall
        case .streaming:
            title = Localizable.upsellCarouselStreamingTitle
            subtitle = Localizable.upsellCarouselStreamingSubtitle
            image = HomeAsset.streamingMobileSmall
        case .netshield:
            title = Localizable.upsellCarouselNetshieldTitle
            subtitle = Localizable.upsellCarouselNetshieldSubtitle
            image = HomeAsset.netshieldMobileSmall
        case .secureCore:
            title = Localizable.upsellCarouselSecureCoreTitle
            subtitle = Localizable.upsellCarouselSecureCoreSubtitle
            image = HomeAsset.secureCoreSmall
        case .p2p:
            title = Localizable.upsellCarouselP2pTitle
            subtitle = Localizable.upsellCarouselP2pSubtitle
            image = HomeAsset.p2pSmall
        case .devices:
            title = Localizable.upsellCarouselDevicesTitle
            subtitle = Localizable.upsellCarouselDevicesSubtitle
            image = HomeAsset.multipleDevicesSmall
        case .tor:
            title = Localizable.upsellCarouselTorTitle
            subtitle = Localizable.upsellCarouselTorSubtitle
            image = HomeAsset.torSmall
        case .more:
            title = Localizable.upsellCarouselMoreTitle
            subtitle = Localizable.upsellCarouselMoreSubtitle
            image = HomeAsset.customisationMobileSmall
        case .plutonium:
            title = Localizable.plutoniumUpsellTitle
            subtitle = Localizable.plutoniumUpsellSubtitle
            image = HomeAsset.customisationMobileSmall
        }
    }
}

fileprivate struct CarouselWidthPreferenceKey: ViewDimensionPreferenceKey { }

#Preview {
    UpsellCarousel { _ in }
}
