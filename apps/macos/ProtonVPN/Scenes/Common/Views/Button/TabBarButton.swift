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
import Ergonomics

class TabBarButton: NSButton {
    static func backgroundColor(forFocus present: Bool) -> CGColor {
        .cgColor(.background, present ? .weak : .normal)
    }
    
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

    override var isEnabled: Bool {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        return .tabGroup
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        isBordered = false
        setButtonType(.momentaryChange)
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        wantsLayer = true
        DarkAppearance {
            layer?.backgroundColor = .cgColor(.background, .transparent)
        }
    }
    
    private func setupAttributedTitle() {
        let shouldHighlight = isFocused || isHovered
        attributedTitle = title.styled(shouldHighlight ? .normal : .weak, font: .themeFont(.heading4))
    }
}
