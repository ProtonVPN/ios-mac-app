//
//  ExpandCellButton.swift
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

class ExpandCellButton: HoverDetectionButton {
    
    var cellState: CellState? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureButton()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if isHovered {
            context.setStrokeColor(NSColor.protonWhite().cgColor)
            context.setFillColor(NSColor.protonGreen().cgColor)
        } else {
            context.setStrokeColor(NSColor.protonLightGrey().cgColor)
        }
        
        context.setLineWidth(2.0)
        var halfArrowHeight = bounds.height / 12
        var halfArrowWidth = bounds.width / 6
        if cellState == .expanded {
            halfArrowHeight = -halfArrowHeight
            halfArrowWidth = -halfArrowWidth
        }
        context.move(to: CGPoint(x: bounds.width / 2 - halfArrowWidth, y: bounds.height / 2 - halfArrowHeight))
        context.addLine(to: CGPoint(x: bounds.width / 2, y: bounds.height / 2 + halfArrowHeight))
        context.addLine(to: CGPoint(x: bounds.width / 2 + halfArrowWidth, y: bounds.height / 2 - halfArrowHeight))
        context.drawPath(using: .stroke)
    }
    
    private func configureButton() {
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        layer?.borderWidth = 2
        layer?.borderColor = isHovered ? NSColor.protonGreen().cgColor : NSColor.protonLightGrey().cgColor
        layer?.backgroundColor = isHovered ? NSColor.protonGreen().cgColor : NSColor.protonGrey().cgColor
    }
}
