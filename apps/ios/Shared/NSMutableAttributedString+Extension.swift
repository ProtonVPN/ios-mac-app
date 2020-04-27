//
//  NSMutableAttributedString+Extension.swift
//  ProtonVPN - Created on 2020-04-27.
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

import Foundation
import UIKit

// MARK: - Text

extension NSMutableAttributedString {
    
    func addTextAttributes(withColor color: UIColor,
                       font: UIFont,
                       alignment: NSTextAlignment = .left,
                       lineSpacing: CGFloat? = nil,
                       lineBreakMode: NSLineBreakMode? = nil) {
        
        let range = (self.string as NSString).range(of: self.string)
        
        self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
        self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
        self.addAttribute(NSAttributedString.Key.backgroundColor, value: UIColor.clear, range: range)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        if let lineBreakMode = lineBreakMode {
            paragraphStyle.lineBreakMode = lineBreakMode
        }
        if let lineSpacing = lineSpacing {
            paragraphStyle.lineSpacing = lineSpacing
        }
        self.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
    }
    
}

// MARK: - Links

extension NSMutableAttributedString {
    
    /// Add a `.link` attribute to a given text
    /// - Parameters:
    ///     - links: Parameters to pass to `add(link: String, withUrl url: String)` method
    public func add(links: [(String, String)]) -> NSMutableAttributedString {
        for (link, url) in links {
            _ = self.add(link: link, withUrl: url)
        }
        return self
    }
    
    /// Add a `.link` attribute to a given text
    /// - Parameters:
    ///     - link: Text that will become a link
    ///     - withUrl: String representation or URL for a link
    public func add(link: String, withUrl: String) -> NSMutableAttributedString {
        let fullText = self.string
        guard let url = URL(string: withUrl), let subrange = fullText.range(of: link) else {
            return self
        }
        let nsRange = NSRange(subrange, in: fullText)
        self.addAttribute(.link, value: url, range: nsRange)
        
        return self
    }
    
}
