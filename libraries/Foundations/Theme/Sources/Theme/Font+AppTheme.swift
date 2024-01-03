//
//  Created on 19/04/2023.
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

public extension AppTheme {
    enum Typography {

#if canImport(Cocoa)

        case largeTitle(emphasised: Bool = false)
        case title1(emphasised: Bool = false)
        case title2(emphasised: Bool = false)
        case title3(emphasised: Bool = false)
        case headline(emphasised: Bool = false)
        case subHeadline(emphasised: Bool = false)
        case body(emphasised: Bool = false)
        case callout(emphasised: Bool = false)
        case footnote(emphasised: Bool = false)

        public static let `default`: Self = .title3()

#elseif canImport(UIKit)

        case hero
        case headline
        case subHeadline
        case body1(Weight = .regular)
        case body2(emphasised: Bool = false)
        case body3(emphasised: Bool = false)
        case caption(emphasised: Bool = false)
        case overline(emphasised: Bool = false)

        public enum Weight {
            case regular
            case semibold
            case bold

            var rawValue: Font.Weight {
                switch self {
                case .regular:
                    return .regular
                case .semibold:
                    return .semibold
                case .bold:
                    return .bold
                }
            }
        }

        public static let `default`: Self = .body3()
#endif
    }
}

public extension Font {
    static func themeFont(_ typography: AppTheme.Typography = .default) -> Font {
        switch typography {

#if canImport(Cocoa)
            // https://developer.apple.com/design/human-interface-guidelines/typography#macOS-built-in-text-styles
        case .largeTitle(let emphasised): // 26
            return .largeTitle.weight(emphasised ? .bold : .regular)
        case .title1(let emphasised): // 22
            return .title.weight(emphasised ? .bold : .regular)
        case .title2(let emphasised): // 17
            return .title2.weight(emphasised ? .bold : .regular)
        case .title3(let emphasised): // 15
            return .title3.weight(emphasised ? .semibold : .regular)
        case .headline(let emphasised): // 13
            return .headline.weight(emphasised ? .bold : .regular)
        case .subHeadline(let emphasised): // 11
            return .subheadline.weight(emphasised ? .semibold : .regular)
        case .body(let emphasised): // 13
            return .body.weight(emphasised ? .semibold : .regular)
        case .callout(let emphasised): // 12
            return .callout.weight(emphasised ? .semibold : .regular)
        case .footnote(let emphasised): // 10
            return .footnote.weight(emphasised ? .semibold : .regular)

#elseif canImport(UIKit)
            // https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
        case .hero: // 28
            return .title.weight(.bold)
        case .headline: // 22
            return .title2.weight(.bold)
        case .subHeadline: // 22
            return .title2.weight(.regular)
        case .body1(let weight): // 17
            return .body.weight(weight.rawValue)
        case .body2(let emphasised): // 15
            return .subheadline.weight(emphasised ? .semibold : .regular)
        case .body3(let emphasised):
            // No matching default typography. Note that semibold might not work here.
            // We either need to accept that or change the size by 1 point up or down.
            return .custom("", size: 14, relativeTo: .body).weight(emphasised ? .semibold : .regular)
        case .caption(let emphasised): // 13
            return .footnote.weight(emphasised ? .semibold : .regular)
        case .overline(let emphasised): // 11
            return .caption2.weight(emphasised ? .semibold : .regular)
#endif
        }
    }
}

public extension Text {
    func themeFont(_ typography: AppTheme.Typography = .default) -> Text {
        return self.font(.themeFont(typography))
    }
}

public extension View {
    @inlinable func font(_ typography: AppTheme.Typography = .default) -> some View {
        return self.font(.themeFont(typography))
    }
}
