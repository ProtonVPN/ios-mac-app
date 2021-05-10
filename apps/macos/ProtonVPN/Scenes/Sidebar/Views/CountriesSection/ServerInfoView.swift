//
//  InfoView.swift
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

class ServerInfoView: NSView {

    var trackingArea: NSTrackingArea?
    var clicked: (() -> Void)?
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        set(enabled: true)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setFillColor(NSColor.protonGreyShade().cgColor)
        
        let contentFrame = CGRect(x: 0.0, y: 15, width: bounds.width, height: bounds.height - 15)
        context.addRect(contentFrame)
        context.move(to: CGPoint(x: 0, y: 15))
        context.addLine(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: 10, y: 15))
        context.closePath()
        context.drawPath(using: .fill)
    }
    
    override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseMoved(with event: NSEvent) {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseExited(with event: NSEvent) {
        addCursorRect(bounds, cursor: .arrow)
    }
    
    override func mouseDown(with event: NSEvent) {
        if convert(event.locationInWindow, from: nil).y < 15 {
            if let clicked = clicked {
                clicked()
            }
        }
    }
}
