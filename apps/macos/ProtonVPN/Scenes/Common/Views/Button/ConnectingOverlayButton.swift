//
//  CancelConnectingButton.swift
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

class ConnectingOverlayButton: HoverDetectionButton {

    override var title: String {
        didSet {
            needsDisplay = true
        }
    }
    
    public var color: NSColor = .protonWhite() {
        didSet {
            needsDisplay = true
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        trackingAreas.forEach {
            removeTrackingArea($0)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = bounds.height / 2
        layer?.borderColor = color.cgColor
        
        let textColor: NSColor
        
        if isHovered {
            layer?.backgroundColor = color.cgColor
            textColor = .protonBlack()
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            textColor = color
        }
        
        attributedTitle = title.attributed(withColor: textColor, fontSize: 16)
    }
}
