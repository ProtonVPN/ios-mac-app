//
//  Created on 2022-03-11.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Cocoa

public extension NSFont {
    static func themeFont(_ semanticSize: AppTheme.FontSize = .paragraph, bold: Bool = false, italic: Bool = false) -> NSFont {
        return themeFont(literalSize: semanticSize.rawValue, bold: bold, italic: italic)
    }

    static func themeFont(literalSize: Double, bold: Bool = false, italic: Bool = false) -> NSFont {
        let result = systemFont(ofSize: literalSize)
        if bold && italic {
            return result.with(.bold, .italic)
        } else if bold {
            return result.with(.bold)
        } else if italic {
            return result.with(.italic)
        } else {
            return result
        }
    }
}
