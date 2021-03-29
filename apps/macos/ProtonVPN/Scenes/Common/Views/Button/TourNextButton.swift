//
//  TourNextButton.swift
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

// MARK: - Used by TourNextButton and its TourNextButtonCell cell
private let textOffset: CGFloat = 16
private let arrowWidth: CGFloat = 4.5

class TourNextButton: HoverDetectionButton {
    
    var showArrow = false {
        didSet {
            if let tourCell = cell as? TourNextButtonCell {
                tourCell.showArrow = showArrow
            }
        }
    }
    
    override var title: String {
        didSet {
            attributedTitle = title.attributed(withColor: .protonGreen(), fontSize: 14)
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = isHovered ? NSColor.protonHoveredWhite().cgColor : NSColor.protonWhite().cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if showArrow {
            let midX = bounds.midX + (attributedTitle.size().width - textOffset - arrowWidth) / 2 + textOffset
            let midY = bounds.midY
            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: midX, y: midY - arrowWidth))
            arrow.addLine(to: CGPoint(x: midX + arrowWidth, y: midY))
            arrow.addLine(to: CGPoint(x: midX, y: midY + arrowWidth))
            arrow.move(to: CGPoint(x: midX + arrowWidth, y: midY))
            arrow.addLine(to: CGPoint(x: midX - arrowWidth, y: midY))
            
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.setStrokeColor(NSColor.protonGreen().cgColor)
            context.addPath(arrow)
            context.drawPath(using: .stroke)
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
}

class TourNextButtonCell: NSButtonCell {
    
    var showArrow = false
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        // center text and move it left to allow the arrow icon to be part of the central alignment of the button's content if shown
        let r = CGRect(origin: rect.origin, size: CGSize(width: rect.width - (showArrow ? (textOffset - arrowWidth) : 0), height: rect.height * 0.95))
        return r
    }
}
