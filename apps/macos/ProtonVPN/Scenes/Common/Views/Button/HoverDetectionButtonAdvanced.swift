//
//  HoverDetectionButtonAdvanced.swift
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

// Use for buttons that shouldn't hover when obscured (less efficient than HoverDetectionButton)
class HoverDetectionButtonAdvanced: NSButton {
    
    var isHovered: Bool = false {
        didSet {
            resetCursorRects()
            needsDisplay = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer?.masksToBounds = false
        
        isBordered = false
        setButtonType(.momentaryChange)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        layer?.masksToBounds = false
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            updateHoveredState(with: event)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        if isEnabled {
            updateHoveredState(with: event)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        discardCursorRects()
        isHovered = false
    }
    
    override func mouseDown(with event: NSEvent) {
        if let mouseInside = mouseInside(with: event), mouseInside {
            super.mouseDown(with: event)
        }
    }
    
    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        updateHoveredState(with: nil)
        
        super.updateTrackingAreas()
    }
    
    override func resetCursorRects() {
        if isHovered {
            addCursorRect(bounds, cursor: .pointingHand)
        } else {
            discardCursorRects()
            NSCursor.arrow.set()
        }
    }
    
    // MARK: - Private
    private func updateHoveredState(with event: NSEvent?) {
        let newHovered = mouseInside(with: event)
        if let newHovered = newHovered, newHovered != isHovered {
            isHovered = newHovered
        }
    }
    
    private func mouseInside(with event: NSEvent?) -> Bool? {
        if let event = event {
            // hit test before hovering incase a view is obscuring this one already
            guard let hitView = window?.contentView?.hitTest(event.locationInWindow) else { return nil }
            
            return hitView === self
        } else {
            guard let window = window else { return nil }
            
            let mouseInWindow = window.mouseLocationOutsideOfEventStream
            let mouseInView = convert(mouseInWindow, from: nil)
            return bounds.contains(mouseInView)
        }
    }
}
