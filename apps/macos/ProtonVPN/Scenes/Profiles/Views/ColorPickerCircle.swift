//
//  ColorPickerCircle.swift
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
import vpncore

class ColorPickerCircle: NSView {
    
    private let radiusIndentation: CGFloat = 3
    private let selectionBorderWidth: CGFloat = 3
    private let selectionBorderColor = NSColor.white.cgColor
    
    var isSelected: Bool? {
        didSet {
            needsDisplay = true
        }
    }
    
    var color: NSColor? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let color = color?.cgColor else {
            return
        }
        
        if bounds.width <= 2 * radiusIndentation {
            PMLog.D("Unable to draw color picker circle with given bounds.", level: .debug)
            return
        }
        
        let drawingRect = bounds
        var radius: CGFloat
        var circleRect: NSRect
        
        if isSelected ?? false {
            let delta: CGFloat = radiusIndentation - selectionBorderWidth
            radius = drawingRect.width / 2 - delta
            circleRect = NSRect(x: drawingRect.origin.x + delta, y: drawingRect.origin.y + delta, width: 2 * radius, height: 2 * radius)
            
            context.addEllipse(in: circleRect)
            context.setFillColor(selectionBorderColor)
            context.drawPath(using: .fill)
        }
        
        radius = drawingRect.width / 2 - radiusIndentation
        circleRect = NSRect(x: drawingRect.origin.x + radiusIndentation, y: drawingRect.origin.y + radiusIndentation, width: 2 * radius, height: 2 * radius)
        
        context.addEllipse(in: circleRect)
        context.setFillColor(color)
        context.drawPath(using: .fill)
    }
}
