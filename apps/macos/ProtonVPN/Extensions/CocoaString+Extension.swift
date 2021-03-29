//
//  String+Extension.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa

extension String {
    
    func attributed(withColor color: NSColor,
                    fontSize: Double,
                    bold: Bool = false,
                    italic: Bool = false,
                    alignment: NSTextAlignment = .center,
                    lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
        let size = CGFloat(fontSize)
        
        var font: NSFont!
        
        if bold {
            font = NSFont.boldSystemFont(ofSize: size)
        } else if italic {
            font = NSFont.italicSystem(ofSize: size)
        } else {
            font = NSFont.systemFont(ofSize: size)
        }
        
        return attributed(withColor: color, font: font, alignment: alignment, lineBreakMode: lineBreakMode)
    }
    
    func attributed(withColor color: NSColor,
                    font: NSFont,
                    alignment: NSTextAlignment = .center,
                    lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
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
