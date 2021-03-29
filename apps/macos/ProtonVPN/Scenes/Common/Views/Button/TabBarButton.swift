//
//  TabBarButton.swift
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

class TabBarButton: NSButton {
    
    override var title: String {
        didSet {
            setupAttributedTitle()
        }
    }
    
    var isFocused: Bool = false {
        didSet {
            setupAttributedTitle()
        }
    }
    
    var isHovered: Bool = false {
        didSet {
            if !isFocused {
                setupAttributedTitle()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        isBordered = false
        setButtonType(.momentaryChange)
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        removeCursorRect(bounds, cursor: .pointingHand)
        isHovered = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    private func setupAttributedTitle() {
        let shouldHighlight = isFocused || isHovered
        attributedTitle = title.attributed(withColor: shouldHighlight ? .protonWhite() : .protonGreyOutOfFocus(), fontSize: 16)
    }
}
