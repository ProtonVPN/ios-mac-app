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
        case .largeTitle(let emphasised):
            return .system(size: 26, weight: emphasised ? .bold : .regular)
        case .title1(let emphasised):
            return .system(size: 22, weight: emphasised ? .bold : .regular)
        case .title2(let emphasised):
            return .system(size: 17, weight: emphasised ? .bold : .regular)
        case .title3(let emphasised):
            return .system(size: 15, weight: emphasised ? .semibold : .regular)
        case .headline(let emphasised):
            return .system(size: 13, weight: emphasised ? .bold : .regular)
        case .subHeadline(let emphasised):
            return .system(size: 11, weight: emphasised ? .semibold : .regular)
        case .body(let emphasised):
            return .system(size: 13, weight: emphasised ? .semibold : .regular)
        case .callout(let emphasised):
            return .system(size: 12, weight: emphasised ? .semibold : .regular)
        case .footnote(let emphasised):
            return .system(size: 10, weight: emphasised ? .semibold : .regular)
        #elseif canImport(UIKit)
        case .hero:
            return .custom("", size: 28, relativeTo: .body).weight(.bold)
        case .headline:
            return .custom("", size: 22, relativeTo: .body).weight(.bold)
        case .subHeadline:
            return .custom("", size: 22, relativeTo: .body).weight(.regular)
        case .body1(let weight):
            return .custom("", size: 17, relativeTo: .body).weight(weight.rawValue)
        case .body2(let emphasised):
            return .custom("", size: 15, relativeTo: .body).weight(emphasised ? .semibold : .regular)
        case .body3(let emphasised):
            return .custom("", size: 14, relativeTo: .body).weight(emphasised ? .semibold : .regular)
        case .caption(let emphasised):
            return .custom("", size: 13, relativeTo: .body).weight(emphasised ? .semibold : .regular)
        case .overline(let emphasised):
            return .custom("", size: 11, relativeTo: .body).weight(emphasised ? .semibold : .regular)
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
