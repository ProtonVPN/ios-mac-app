//
//  PVPNTextViewLink.swift
//  ProtonVPN - Created on 13.05.20.
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

class PVPNTextViewLink: NSTextView {

    public var lineSpacing: CGFloat = 14
    public var textViewFont = NSFont.systemFont(ofSize: 14)
    public var textViewTextColor = NSColor.protonWhite()

    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    public func hyperLink(originalText: String, hyperLink: String, urlString: String) {
        let attributedOriginalText = NSMutableAttributedString(string: originalText)
        let linkRange = attributedOriginalText.mutableString.range(of: hyperLink)
        let fullRange = NSRange(location: 0, length: attributedOriginalText.length)
        attributedOriginalText.addAttribute(NSAttributedString.Key.font, value: textViewFont, range: fullRange)
        attributedOriginalText.addAttribute(NSAttributedString.Key.foregroundColor, value: textViewTextColor, range: fullRange)
        attributedOriginalText.addAttribute(NSAttributedString.Key.link, value: urlString, range: linkRange)
        attributedOriginalText.addAttribute(NSAttributedString.Key.paragraphStyle, value: defaultStyle, range: fullRange)

        self.textStorage?.setAttributedString(attributedOriginalText)
    }

    // MARK: - Private
    private var defaultStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = self.lineSpacing / self.textViewFont.pointSize
        style.alignment = .left
        return style
    }

    private func setup() {
        isEditable = false
        isSelectable = true
        isAutomaticLinkDetectionEnabled = true

        guard let text = self.textStorage?.string, !text.isEmpty else { return }
        let titleAttributes = [NSAttributedString.Key.font: self.textViewFont,
                               NSAttributedString.Key.foregroundColor: self.textColor ?? textViewTextColor,
                               NSAttributedString.Key.paragraphStyle: defaultStyle]

        let titleString = NSAttributedString(string: text, attributes: titleAttributes)
        self.textStorage?.setAttributedString(titleString)
    }
    
}
