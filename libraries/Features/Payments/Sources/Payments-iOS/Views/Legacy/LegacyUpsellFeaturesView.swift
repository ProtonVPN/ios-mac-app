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

struct LegacyUpsellFeaturesView: View {
    let features: [UpsellFeature]

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            ForEach(features) { feature in
                let style = style(for: feature)
                HStack(spacing: .themeSpacing8) {
                    if let image = feature.image {
                        image.swiftUIImage.foregroundColor(style.iconColor)
                    }
                    if let attributedTitle = attributedTitle(for: feature) {
                        Text(attributedTitle).foregroundColor(style.textColor)
                    }
                }
            }
        }
        .padding(.vertical, .themeSpacing16)
        .padding(.horizontal, .themeSpacing24)
        .themeBorder(cornerRadius: .radius12)
    }

    private func attributedTitle(for feature: UpsellFeature) -> AttributedString? {
        let markdown = feature.boldTitleElements()
            .reduce(into: feature.title()) { partialResult, boldPart in
                partialResult = partialResult.replacingOccurrences(of: boldPart, with: "**\(boldPart)**")
            }
        return try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    }

    private func style(for feature: UpsellFeature) -> (iconColor: Color, textColor: Color) {
        if feature == .moneyGuarantee {
            return (Color(.icon, .success), Color(.text, .success))
        }
        return (Color(.icon, [.interactive, .active]), Color(.text))
    }
}
