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

import Modals
import Theme

import SwiftUI

struct ModalBodyView: View {
    let modalType: ModalType
    let modalModel: ModalModel

    private let displayBodyFeatures: Bool
    private let imagePadding: EdgeInsets?

    private let onFeatureUpdate: ((Feature) -> Void)?

    init(
        modalType: ModalType,
        displayBodyFeatures: Bool = true,
        imagePadding: EdgeInsets? = nil,
        onFeatureUpdate: ((Feature) -> Void)? = nil
    ) {
        self.modalType = modalType
        self.modalModel = modalType.modalModel()
        self.displayBodyFeatures = displayBodyFeatures
        self.imagePadding = imagePadding
        self.onFeatureUpdate = onFeatureUpdate
    }

    var body: some View {
        if modalType.shouldVerticallyCenterContent {
            VerticallyCenteringScrollView {
                content
            }
            .padding(.horizontal, .themeSpacing16)
        } else {
            ScrollView {
                content.frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            headerView

            Group {
                mainContent

                Spacer().frame(height: .themeSpacing24)

                if displayBodyFeatures {
                    featuresContentView
                }
            }
            .padding(.horizontal, .themeSpacing16)
        }
    }

    private var headerView: some View {
        ZStack {
            if let imagePadding {
                modalType.artImage().padding(imagePadding)
            } else {
                modalType.artImage()
            }

            if !modalType.shouldVerticallyCenterContent {
                LinearGradient(
                    colors: [
                        Theme.Asset.onboardingGradientTop.swiftUIColor,
                        Theme.Asset.onboardingGradientBottom.swiftUIColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
    }

    @ViewBuilder
    private var mainContent: some View {
        if let (stepCount, totalStepCount) = modalType.multipleStepsModal {
            VStack(spacing: .themeSpacing8) {
                ProgressView(value: Double(stepCount) / Double(totalStepCount))
                    .progressViewStyle(.linear)
                    .tint(Asset.onboardingTint.swiftUIColor)
                    .padding(.top, .themeSpacing8)

                Text("Step \(stepCount) of \(totalStepCount)")
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.caption(emphasised: false))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, .themeSpacing8)
            }
            .padding(.vertical, .themeSpacing24)
        }

        VStack(spacing: .themeSpacing8) {
            Text(modalModel.title)
                .themeFont(.headline)
                .multilineTextAlignment(.center)
            if let subtitle = modalModel.subtitle?.attributedString {
                Text(subtitle)
                    .themeFont(.body1(.regular))
                    .foregroundColor(subtitleContentColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, .themeSpacing16)
    }

    @ViewBuilder
    private var featuresContentView: some View {
        let features = modalModel.features
        if shouldDisplaySpecificFeatures(features) {
            VStack(alignment: .leading, spacing: .zero) {
                ForEach(features) { feature in
                    if case .banner = feature {
                        BannerView(useAlternateWording: shouldBannerUseAlternateWording)
                    } else if case let .toggle(id, title, subtitle, initialState) = feature {
                        ToggleFeatureView(title: title, subtitle: subtitle, initialState: initialState) { newValue in
                            onFeatureUpdate?(.toggle(id: id, title: title, subtitle: subtitle, state: newValue))
                        }
                        .onAppear {
                            onFeatureUpdate?(feature) // initial call
                        }
                    }
                }
            }
        } else if !features.isEmpty {
            ModalFeaturesView(features: features)
        }
    }

    private func shouldDisplaySpecificFeatures(_ features: some Collection<Feature>) -> Bool {
        return features.contains { feature in
            switch feature {
            case .banner:
                return true
            case .toggle:
                return true
            default:
                return false
            }
        }
    }

    private var shouldBannerUseAlternateWording: Bool {
        switch modalType {
        case .onboardingWelcome:
            return true
        default:
            return false
        }
    }

    private var subtitleContentColor: Color {
        switch modalType {
        case .onboardingWelcome, .onboardingGetStarted:
            return .white
        default:
            return Color(.text, .weak)
        }
    }
}

private extension ModalModel.Subtitle {
    var attributedString: AttributedString? {
        let markdown = boldText
            .reduce(into: text) { partialResult, boldPart in
                partialResult = partialResult.replacingOccurrences(of: boldPart, with: "**\(boldPart)**")
            }
        return try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    }
}

struct ModalBody_Previews: PreviewProvider {
    static var previews: some View {
        ModalBodyView(modalType: .onboardingGetStarted)
            .previewDisplayName("ModalBody")
    }
}
