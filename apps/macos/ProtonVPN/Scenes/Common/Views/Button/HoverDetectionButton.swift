//
//  HoverDetectionButton.swift
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

class HoverDetectionButton: NSButton {
    
    // Adds padding between text and button border
    @IBInspectable var horizontalPadding: CGFloat = 0
    @IBInspectable var verticalPadding: CGFloat = 0

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += self.horizontalPadding
        size.height += self.verticalPadding
        return size
    }

    override var isEnabled: Bool {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    private var trackingArea: NSTrackingArea? {
        willSet {
            if trackingArea != nil {
                removeTrackingArea(trackingArea!)
            }
            if newValue != nil {
                addTrackingArea(newValue!)
            }
        }
    }
    
    var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer?.masksToBounds = false
        
        isBordered = false
        setButtonType(.momentaryChange)
        
        addMouseTracking()
    }
    
    private func addMouseTracking() {
        trackingArea = NSTrackingArea(rect: bounds, options: trackingOptions(), owner: self, userInfo: nil)
    }
    
    func trackingOptions() -> NSTrackingArea.Options {
        return [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.activeAlways]
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        addMouseTracking()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        layer?.masksToBounds = false
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            isHovered = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }
}
