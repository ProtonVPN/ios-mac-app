//
//  Created on 29/06/2026 by Max Kupetskyi.
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

import SDWebImageSwiftUI
import Strings
import SwiftUI
import Theme

public struct AnnouncementDetailView: View {
    private let panel: OfferPanel.LegacyPanel
    private let onAction: () -> Void
    private let onClose: () -> Void

    public init(
        panel: OfferPanel.LegacyPanel,
        onAction: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.panel = panel
        self.onAction = onAction
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: .themeSpacing16) {
                    incentive
                    pill
                    picture
                    Text(panel.title)
                        .font(DetailFonts.title)
                        .foregroundStyle(Color(.text))
                        .multilineTextAlignment(.center)
                    features
                    Text(panel.featuresFooter)
                        .font(DetailFonts.footnote)
                        .foregroundStyle(Color(.text, .weak))
                        .multilineTextAlignment(.center)
                }
                .padding(.themeSpacing16)
                .padding(.top, .themeSpacing32)
            }
            .safeAreaInset(edge: .bottom) { footer }

            AnnouncementCloseButton(action: onClose)
                .padding(.themeSpacing16)
        }
        .background(Color(.background, .weak))
    }

    // MARK: - Sections

    /// Renders the incentive copy, substituting the `%IncentivePrice%` token with the price line
    /// (emphasised copy around a larger price line), matching the legacy attributed-string layout
    private var incentive: some View {
        let parts = panel.incentive.components(separatedBy: "%IncentivePrice%")
        return Group {
            if parts.count == 1 {
                Text(panel.incentive)
                    .themeFont(DetailFonts.incentive)
            } else {
                Text(parts[0]).themeFont(DetailFonts.incentive)
                    + Text("\n")
                    + Text(panel.incentivePrice).themeFont(DetailFonts.price)
                    + Text(parts.dropFirst().joined()).themeFont(DetailFonts.incentive)
            }
        }
        .foregroundStyle(Color(.text))
        .multilineTextAlignment(.center)
    }

    private var pill: some View {
        Text(panel.pill)
            .font(DetailFonts.pill)
            .foregroundStyle(Color(.text))
            .padding(.horizontal, .themeSpacing12)
            .padding(.vertical, .themeSpacing8)
            .background(Color(.background, .danger))
            .clipShape(.capsule)
    }

    @ViewBuilder
    private var picture: some View {
        if let url = URL(string: panel.pictureURL) {
            WebImage(url: url)
                .resizable()
                .scaledToFit()
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            ForEach(Array(panel.features.enumerated()), id: \.offset) { _, feature in
                AnnouncementFeatureRow(feature: feature)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: .themeSpacing8) {
            Button(panel.button.text ?? Localizable.ok, action: onAction)
                .buttonStyle(.borderedProminent)
            if !panel.pageFooter.isEmpty {
                Text(panel.pageFooter)
                    .font(DetailFonts.footnote)
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.themeSpacing16)
        .frame(maxWidth: .infinity)
        .background(Color(.background, .weak))
    }
}

/// A single `OfferFeature` row: remote icon + text
struct AnnouncementFeatureRow: View {
    let feature: OfferFeature

    var body: some View {
        HStack(spacing: .themeSpacing12) {
            if let url = URL(string: feature.iconURL) {
                WebImage(url: url)
                    .resizable()
                    .scaledToFit()
                    .frame(.square(.themeSpacing24))
            }
            Text(feature.text)
                .font(DetailFonts.feature)
                .foregroundStyle(Color(.text))
            Spacer(minLength: 0)
        }
    }
}

private enum DetailFonts {
    #if os(iOS)
        /// Offer title — 22pt bold.
        static let title: AppTheme.Typography = .headline
        /// Incentive copy — 13pt semibold.
        static let incentive: AppTheme.Typography = .caption(emphasised: true)
        /// Incentive price — 28pt bold.
        static let price: AppTheme.Typography = .hero
        /// Danger pill — 13pt semibold.
        static let pill: AppTheme.Typography = .caption(emphasised: true)
        /// Footer captions — 13pt regular.
        static let footnote: AppTheme.Typography = .caption()
        /// Feature row text — 17pt regular.
        static let feature: AppTheme.Typography = .body1()
    #elseif os(macOS)
        /// Offer title — 22pt bold.
        static let title: AppTheme.Typography = .title1(emphasised: true)
        /// Incentive copy — 13pt emphasised.
        static let incentive: AppTheme.Typography = .headline(emphasised: true)
        /// Incentive price — 26pt (Cocoa has no 28pt; bold dropped at this size).
        static let price: AppTheme.Typography = .largeTitle()
        /// Danger pill — 11pt semibold.
        static let pill: AppTheme.Typography = .subHeadline(emphasised: true)
        /// Footer captions — 10pt regular.
        static let footnote: AppTheme.Typography = .footnote()
        /// Feature row text — 13pt.
        static let feature: AppTheme.Typography = .body()
    #endif
}
