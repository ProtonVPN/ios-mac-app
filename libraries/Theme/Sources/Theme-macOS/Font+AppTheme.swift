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

import Theme
import SwiftUI

public extension AppTheme {
    enum Typography {
        case largeTitle(emphasised: Bool = false)
        case title1(emphasised: Bool = false)
        case title2(emphasised: Bool = false)
        case title3(emphasised: Bool = false)
        case headline(emphasised: Bool = false)
        case subHeadline(emphasised: Bool = false)
        case body(emphasised: Bool = false)
        case callout(emphasised: Bool = false)
        case footnote(emphasised: Bool = false)
    }
}

public extension Font {
    static func themeFont(_ typography: AppTheme.Typography = .title3()) -> Font {
        switch typography {
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
        }
    }
}

public extension Text {
    func themeFont(_ typography: AppTheme.Typography = .title3()) -> Text {
        return self.font(.themeFont(typography))
    }
}
extension View {
    @inlinable public func font(_ typography: AppTheme.Typography = .title3()) -> some View {
        return self.font(.themeFont(typography))
    }
}
