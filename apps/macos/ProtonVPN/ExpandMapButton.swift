//
//  ExpandMapButton.swift
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

enum ExpandMapButtonState {
    case expanded
    case compact
}

class ExpandMapButton: HoverDetectionButton {

    var expandState: ExpandMapButtonState = .compact {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setStrokeColor(NSColor.protonGreyOutOfFocus().cgColor)
        context.setFillColor(NSColor.protonGrey().cgColor)
        
        context.setLineWidth(1.5)
        var halfArrowHeight = bounds.height / 6
        var halfArrowWidth = bounds.width / 12
        if expandState == .expanded {
            halfArrowHeight = -halfArrowHeight
            halfArrowWidth = -halfArrowWidth
            
            context.addEllipse(in: bounds)
            context.addRect(CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width / 2, height: bounds.height))
            context.drawPath(using: .fill)
            
            context.move(to: CGPoint(x: bounds.width * 0.45 - halfArrowWidth, y: bounds.height / 2 - halfArrowHeight))
            context.addLine(to: CGPoint(x: bounds.width * 0.45 + halfArrowWidth, y: bounds.height / 2))
            context.addLine(to: CGPoint(x: bounds.width * 0.45 - halfArrowWidth, y: bounds.height / 2 + halfArrowHeight))
        } else {
            context.addEllipse(in: bounds)
            context.addRect(CGRect(x: bounds.origin.x + bounds.width / 2, y: bounds.origin.y, width: bounds.width / 2, height: bounds.height))
            context.drawPath(using: .fill)
            
            context.move(to: CGPoint(x: bounds.width * 0.55 - halfArrowWidth, y: bounds.height / 2 - halfArrowHeight))
            context.addLine(to: CGPoint(x: bounds.width * 0.55 + halfArrowWidth, y: bounds.height / 2))
            context.addLine(to: CGPoint(x: bounds.width * 0.55 - halfArrowWidth, y: bounds.height / 2 + halfArrowHeight))
        }
        
        context.drawPath(using: .stroke)
    }
}
