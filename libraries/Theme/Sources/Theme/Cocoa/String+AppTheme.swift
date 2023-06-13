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

#if canImport(Cocoa)
import Cocoa

public extension String {
    func styled(_ style: AppTheme.Style = .normal, context: AppTheme.Context = .text, font: NSFont = .themeFont(), hover: Bool = false, alignment: NSTextAlignment = .center, lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
        var style = style
        if hover {
            style.insert(.hovered)
        }

        let color: NSColor = .color(context, style)
        let newString = NSMutableAttributedString(string: self)
        let range = (self as NSString).range(of: self)
        newString.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
        newString.addAttribute(NSAttributedString.Key.font, value: font, range: range)
        newString.addAttribute(NSAttributedString.Key.backgroundColor, value: NSColor.clear, range: range)

        if let lineBreakMode = lineBreakMode {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = lineBreakMode
            newString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
        newString.setAlignment(alignment, range: range)
        return newString
    }
}

public extension CustomStyleContext {
    func style(_ text: String, context: AppTheme.Context = .text, font: NSFont = .themeFont(), hover: Bool = false, alignment: NSTextAlignment = .center, lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
        text.styled(self.customStyle(context: context), context: context, font: font, hover: hover, alignment: alignment, lineBreakMode: lineBreakMode)
    }
}

#endif
