//
//  WhiteHoverLinkButton.swift
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

class WhiteHoverLinkButton: NSButton {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Setup tracking area
        let trackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeAlways], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            var attributes = attributedTitle.attributes(at: 0, longestEffectiveRange: nil, in: NSRange(location: 0, length: attributedTitle.length))
            attributes[NSAttributedString.Key.foregroundColor] = NSColor.protonWhite()
            attributedTitle = NSAttributedString(string: attributedTitle.string, attributes: attributes)
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        var attributes = attributedTitle.attributes(at: 0, longestEffectiveRange: nil, in: NSRange(location: 0, length: attributedTitle.length))
        attributes[NSAttributedString.Key.foregroundColor] = NSColor.protonGreen()
        attributedTitle = NSAttributedString(string: attributedTitle.string, attributes: attributes)
        addCursorRect(bounds, cursor: .arrow)
    }
}
