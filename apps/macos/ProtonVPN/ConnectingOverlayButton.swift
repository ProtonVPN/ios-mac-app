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

    enum Style {
        case main
        case colorGreen
        
        func borderColor(hovered: Bool) -> NSColor {
            switch self {
            case .main: return .protonWhite()
            case .colorGreen:
                return hovered
                    ? .protonGreen()
                    : .white
            }
        }
        
        func backgroundColor(hovered: Bool) -> NSColor {
            switch self {
            case .main: return hovered
                ? .protonWhite()
                : NSColor.clear
            case .colorGreen: return NSColor.clear
            }
        }
        
        func textColor(hovered: Bool) -> NSColor {
            switch self {
            case .main: return hovered
                ? .protonBlack()
                : .protonWhite()
            case .colorGreen: return hovered
                ? .protonGreen()
                : .protonWhite()
            }
        }
        
        func textSize(hovered: Bool) -> Double {
            return 16.0
        }
        
    }
    
    public var style: Style = .main {
        didSet {
            needsDisplay = true
        }
    }
    
    override var title: String {
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
        
        layer?.backgroundColor = style.backgroundColor(hovered: isHovered).cgColor
        layer?.borderColor = style.borderColor(hovered: isHovered).cgColor
        attributedTitle = title.attributed(withColor: style.textColor(hovered: isHovered), fontSize: style.textSize(hovered: isHovered))
    }
    
}
