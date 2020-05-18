//
//  String+Extension.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import vpncore

extension String {
    
    public func attributed(withColor color: UIColor,
                    fontSize: CGFloat,
                    bold: Bool = false,
                    alignment: NSTextAlignment = .natural,
                    lineSpacing: CGFloat? = nil,
                    lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        return attributed(withColor: color, font: font, alignment: alignment, lineSpacing: lineSpacing, lineBreakMode: lineBreakMode)
    }
    
    func attributed(withColor color: UIColor,
                    font: UIFont,
                    alignment: NSTextAlignment = .natural,
                    lineSpacing: CGFloat? = nil,
                    lineBreakMode: NSLineBreakMode? = nil) -> NSAttributedString {
        
        let newString = NSMutableAttributedString(string: self)
        newString.addTextAttributes(withColor: color, font: font, alignment: alignment, lineSpacing: lineSpacing, lineBreakMode: lineBreakMode)
        return newString
    }
    
    func attributedCurrency(withNumberColor numberColor: UIColor,
                            numberFont: UIFont,
                            withTextColor textColor: UIColor,
                            textFont: UIFont
                            ) -> NSAttributedString {
        
        let newString = NSMutableAttributedString(string: self)
        
        let range = (self as NSString).range(of: self)
        newString.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: range)
        newString.addAttribute(NSAttributedString.Key.font, value: textFont, range: range)
        newString.addAttribute(NSAttributedString.Key.backgroundColor, value: UIColor.clear, range: range)
        
        if let range2 = self.range(of: #"\d[\d ,\.]*\d"#, options: .regularExpression) {
            let nsRange = NSRange(range2, in: self)
            newString.addAttribute(NSAttributedString.Key.foregroundColor, value: numberColor, range: nsRange)
            newString.addAttribute(NSAttributedString.Key.font, value: numberFont, range: nsRange)
        }
        
        return newString
    }
    
}
