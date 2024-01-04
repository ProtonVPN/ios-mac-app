//
//  Created on 14/09/2023.
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

#if os(iOS)
import UIKit

public extension String {
    func attributedString(size: CGFloat, color: UIColor, boldStrings: [String]) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .regular),
            .foregroundColor: color
        ]
        let attributedText = NSMutableAttributedString(string: self, attributes: attrs)
        for boldText in boldStrings {
            let range = (self as NSString).range(of: boldText)
            let attrsBold: [NSAttributedString.Key: Any] = [
                .font : UIFont.systemFont(ofSize: size, weight: .bold)
            ]
            attributedText.addAttributes(attrsBold, range: range)
        }
        return attributedText
    }
}
#elseif os(macOS)
import AppKit

public extension String {
    func attributedString(size: CGFloat, color: NSColor, boldStrings: [String], alignment: NSTextAlignment = .natural) -> NSAttributedString {
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .regular),
            .paragraphStyle : paragraphStyle,
            .foregroundColor: color
        ]
        let attributedText = NSMutableAttributedString(string: self, attributes: attrs)
        for boldText in boldStrings {
            let range = (self as NSString).range(of: boldText)
            let attrsBold: [NSAttributedString.Key: Any] = [
                .font : NSFont.systemFont(ofSize: size, weight: .bold)
            ]
            attributedText.addAttributes(attrsBold, range: range)
        }
        return attributedText
    }
}
#endif
