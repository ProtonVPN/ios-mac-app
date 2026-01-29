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

            /// This font uses the system large title style with size 26
            /// - Parameter emphasised: When `true`, uses bold weight; when `false`, uses regular weight
            case largeTitle(emphasised: Bool = false)
            /// This font uses the system title style with size 22
            /// - Parameter emphasised: When `true`, uses bold weight; when `false`, uses regular weight
            case title1(emphasised: Bool = false)
            /// This font uses the system title2 style with size 17
            /// - Parameter emphasised: When `true`, uses bold weight; when `false`, uses regular weight
            case title2(emphasised: Bool = false)
            /// This font uses the system title3 style with size 15
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case title3(emphasised: Bool = false)
            /// This font uses the system headline style with size 13
            /// - Parameter emphasised: When `true`, uses bold weight; when `false`, uses regular weight
            case headline(emphasised: Bool = false)
            /// This font uses the system subheadline style with size 11
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case subHeadline(emphasised: Bool = false)
            /// This font uses the system body style with size 13
            /// - Parameter emphasised: When `true`, uses medium weight; when `false`, uses light weight
            case body(emphasised: Bool = false)
            /// This font uses the system callout style with size 12
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case callout(emphasised: Bool = false)
            /// This font uses the system footnote style with size 10
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case footnote(emphasised: Bool = false)

            public static let `default`: Self = .title3()

        #elseif canImport(UIKit)

            /// This font uses the system title style with bold weight and size 28
            case hero
            /// This font uses the system title2 style with bold weight and size 22
            case headline
            /// This font uses the system title2 style with regular weight and size 22
            case subHeadline
            /// This font uses the system body style with configurable weight and size 17
            case body1(Weight = .regular)
            /// This font uses the system subheadline style with size 15
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case body2(emphasised: Bool = false)
            /// This font uses a custom style with size 14
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case body3(emphasised: Bool = false)
            /// This font uses the system footnote style with size 13
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case caption(emphasised: Bool = false)
            /// This font uses the system caption2 style with size 11
            /// - Parameter emphasised: When `true`, uses semibold weight; when `false`, uses regular weight
            case overline(emphasised: Bool = false)

            public enum Weight {
                case regular
                case semibold
                case bold

                var rawValue: Font.Weight {
                    switch self {
                    case .regular:
                        .regular
                    case .semibold:
                        .semibold
                    case .bold:
                        .bold
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
            case let .largeTitle(emphasised): // 26
                return .largeTitle.weight(emphasised ? .bold : .regular)
            case let .title1(emphasised): // 22
                return .title.weight(emphasised ? .bold : .regular)
            case let .title2(emphasised): // 17
                return .title2.weight(emphasised ? .bold : .light)
            case let .title3(emphasised): // 15
                return .title3.weight(emphasised ? .semibold : .light)
            case let .headline(emphasised): // 13
                return .headline.weight(emphasised ? .bold : .regular)
            case let .subHeadline(emphasised): // 11
                return .subheadline.weight(emphasised ? .semibold : .regular)
            case let .body(emphasised): // 13
                return .body.weight(emphasised ? .medium : .light)
            case let .callout(emphasised): // 12
                return .callout.weight(emphasised ? .semibold : .regular)
            case let .footnote(emphasised): // 10
                return .footnote.weight(emphasised ? .semibold : .regular)

        #elseif canImport(UIKit)
            // https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
            case .hero: // 28
                return .title.weight(.bold)
            case .headline: // 22
                return .title2.weight(.bold)
            case .subHeadline: // 22
                return .title2.weight(.regular)
            case let .body1(weight): // 17
                return .body.weight(weight.rawValue)
            case let .body2(emphasised): // 15
                return .subheadline.weight(emphasised ? .semibold : .regular)
            case let .body3(emphasised):
                // No matching default typography. Note that semibold might not work here.
                // We either need to accept that or change the size by 1 point up or down.
                return .custom("", size: 14, relativeTo: .body).weight(emphasised ? .semibold : .regular)
            case let .caption(emphasised): // 13
                return .footnote.weight(emphasised ? .semibold : .regular)
            case let .overline(emphasised): // 11
                return .caption2.weight(emphasised ? .semibold : .regular)
        #endif
        }
    }
}

public extension Text {
    func themeFont(_ typography: AppTheme.Typography = .default) -> Text {
        font(.themeFont(typography))
    }
}

public extension View {
    @inlinable
    func font(_ typography: AppTheme.Typography = .default) -> some View {
        font(.themeFont(typography))
    }
}
