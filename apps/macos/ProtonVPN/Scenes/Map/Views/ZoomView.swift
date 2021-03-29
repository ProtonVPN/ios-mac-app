//
//  ZoomView.swift
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

enum Orientation {
    case vertical
    case horizontal
}

class ZoomView: NSView {
    
    private let buttonWidth: CGFloat = 20
    
    let zoomInButton: ZoomButton
    let zoomOutButton: ZoomButton
    
    var orientation = Orientation.horizontal {
        didSet {
            needsDisplay = true
        }
    }
    
    var zoomLevels: CGFloat = 8
        
    var zoom: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder decoder: NSCoder) {
        zoomInButton = ZoomButton(type: .in)
        zoomOutButton = ZoomButton(type: .out)
        
        super.init(coder: decoder)
        
        addSubview(zoomInButton)
        addSubview(zoomOutButton)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = super.hitTest(point) {
            if view == self {
                return nil
            } else {
                return view
            }
        }
        return nil
    }
    
    override func viewWillDraw() {
        positionButtons()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        let tickHeight: CGFloat = 6
        context.setLineWidth(1.0)
        context.setStrokeColor(NSColor.protonLightGrey().cgColor)
        
        let stepHeight: CGFloat = 10
        let zoomStep = zoom + 1
        
        let length = bounds.height - buttonWidth * 2
        var tickStart: CGPoint
        var tickEnd: CGPoint
        
        for i in 1...Int(zoomLevels + 0.5) {
            if orientation == .vertical {
                tickStart = CGPoint(x: bounds.width - buttonWidth + (buttonWidth - tickHeight) / 2, y: buttonWidth + CGFloat(i) * length / (zoomLevels + 1))
                tickEnd = CGPoint(x: tickStart.x + tickHeight, y: tickStart.y)
            } else {
                tickStart = CGPoint(x: buttonWidth + CGFloat(i) * length / (zoomLevels + 1), y: bounds.height - buttonWidth + (buttonWidth - tickHeight) / 2)
                tickEnd = CGPoint(x: tickStart.x, y: tickStart.y + tickHeight)
            }
            context.move(to: tickStart)
            context.addLine(to: tickEnd)
        }
        context.drawPath(using: .stroke)
        
        context.setLineWidth(2.0)
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        
        if orientation == .vertical {
            tickStart = CGPoint(x: bounds.width - buttonWidth + (buttonWidth - stepHeight) / 2, y: buttonWidth + CGFloat(zoomStep) * length / (zoomLevels + 1))
            tickEnd = CGPoint(x: tickStart.x + stepHeight, y: tickStart.y)
        } else {
            tickStart = CGPoint(x: buttonWidth + zoomStep * length / (zoomLevels + 1), y: bounds.height - buttonWidth + (buttonWidth - stepHeight) / 2)
            tickEnd = CGPoint(x: tickStart.x, y: tickStart.y + stepHeight)
        }
        context.move(to: tickStart)
        context.addLine(to: tickEnd)
        context.drawPath(using: .stroke)
    }
    
    private func positionButtons() {
        zoomInButton.frame = CGRect(x: bounds.width - 20, y: bounds.height - 20, width: 20, height: 20)
        
        if orientation == .vertical {
            zoomOutButton.frame = CGRect(x: bounds.width - 20, y: 0, width: 20, height: 20)
        } else {
            zoomOutButton.frame = CGRect(x: 0, y: bounds.height - 20, width: 20, height: 20)
        }
    }
    
    // MARK: - Accessibility
    
    override func accessibilityChildren() -> [Any]? {
        return nil
    }
    
    override func isAccessibilityElement() -> Bool {
        return false
    }
}
