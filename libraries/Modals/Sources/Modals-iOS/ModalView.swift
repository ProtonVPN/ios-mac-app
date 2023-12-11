//
//  Created on 21/08/2023.
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
import SharedViews
import Strings
import Theme
import Modals
import ProtonCoreUIFoundations

struct ModalView: View {

    let upsellType: UpsellType

    var gotItAction: (() -> Void)?

    var body: some View {
        UpsellBackgroundView(showGradient: upsellType.shouldAddGradient()) {
            VStack(spacing: .themeSpacing16) {
                ModalBodyView(upsellType: upsellType)
                ModalButtonsView(gotItAction: gotItAction)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeRadius16)
        }
        .background(Color(.background))
    }
}

struct ModalView_Previews: PreviewProvider {
    static var previews: some View {
        ModalView(upsellType: .welcomePlus(numberOfServers: 1800,
                                           numberOfDevices: 10,
                                           numberOfCountries: 68),
                  gotItAction: { })
        .previewDisplayName("Welcome plus")

        ModalView(upsellType: .welcomeUnlimited,
                  gotItAction: { })
        .previewDisplayName("Welcome unlimited")
    }
}

struct ModalButtonsView: View {

    var gotItAction: (() -> Void)?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Button {
            if let gotItAction {
                gotItAction()
            } else {
                dismiss()
            }
        } label: {
            Text(Localizable.gotIt)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct ModalButtons_Previews: PreviewProvider {
    static var previews: some View {
        ModalButtonsView(gotItAction: { })
            .previewDisplayName("ModalButtons")
    }
}

struct ModalBodyView: View {
    
    let upsellType: UpsellType

    var body: some View {
        VerticallyCenteringScrollView {
            VStack(spacing: .themeSpacing24) {
                upsellType.artImage()
                
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

struct BannerView: View {

    var body: some View {
        HStack(alignment: .top, spacing: .themeSpacing12) {
            Asset.bannerIcon.swiftUIImage
            VStack {
                HStack {
                    Text(Localizable.welcomeToProtonBannerTitle)
                    IconProvider.arrowOutSquare.swiftUIImage
                }
                Text(Localizable.welcomeToProtonBannerSubtitle)
            }
        }
        .padding(.vertical, .themeSpacing16)
        .padding(.horizontal, .themeSpacing24)
        .background(Color(.background, .weak))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.radius12.rawValue))
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
                        .foregroundStyle(Color(.icon, green ? .success : [.interactive, .active]))
                    if let title = try? AttributedString(markdown: feature.title()) {
                        Text(title)
                            .foregroundStyle(Color(.text, green ? .success : []))
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
        ModalFeaturesView(features: [.accessLAN, .activityLogging, .addLayer])
            .previewDisplayName("Modal Features")
    }
}

/// Vertical scroll view with content centred vertically
///
struct VerticallyCenteringScrollView<Content>: View where Content: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
            }
        }
    }
}

struct UpsellBackgroundView<Content>: View where Content: View {
    let showGradient: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            if showGradient {
                VStack(spacing: 0) {
                    gradient
                    Spacer()
                }
                .ignoresSafeArea()
            }
            content
        }
    }

    var gradient: some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return Color.clear
            .aspectRatio(isPad ? 2 : 1, contentMode: .fit)
            .background(
                ZStack {
                    let gradient = Gradient(colors: [Asset.upsellGradientTop.swiftUIColor,
                                                     Asset.upsellGradientBottom.swiftUIColor])
                    LinearGradient(gradient: gradient,
                                   startPoint: .top,
                                   endPoint: .bottom)
                    .opacity(0.4)
                    let fadingGradient = Gradient(colors: [.clear, Color(.background)])
                    LinearGradient(gradient: fadingGradient,
                                   startPoint: .top,
                                   endPoint: .bottom)
                }
            )
    }
}
