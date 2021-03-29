//
//  ZoomButton.swift
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

enum ZoomType {
    case `in`
    case out
}

class ZoomButton: NSButton {
    
    let zoomType: ZoomType
    
    override var frame: NSRect {
        didSet {
            needsDisplay = true
        }
    }
    
    init(type zoomType: ZoomType) {
        self.zoomType = zoomType
        
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        isTransparent = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        let plusButtonFrame = CGRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height - 1)
        context.setLineWidth(1.0)
        context.setStrokeColor(NSColor.protonLightGrey().cgColor)
        context.addRect(plusButtonFrame)
        context.drawPath(using: .stroke)
        
        context.setLineWidth(2.0)
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        context.move(to: CGPoint(x: plusButtonFrame.origin.x + plusButtonFrame.width / 4, y: plusButtonFrame.origin.y + plusButtonFrame.height / 2))
        context.addLine(to: CGPoint(x: plusButtonFrame.origin.x + 3 * plusButtonFrame.width / 4, y: plusButtonFrame.origin.y + plusButtonFrame.height / 2))
        
        if zoomType == .in {
            context.move(to: CGPoint(x: plusButtonFrame.origin.x + plusButtonFrame.width / 2, y: plusButtonFrame.origin.y + plusButtonFrame.height / 4))
            context.addLine(to: CGPoint(x: plusButtonFrame.origin.x + plusButtonFrame.width / 2, y: plusButtonFrame.origin.y + 3 * plusButtonFrame.height / 4))
        }
        
        context.drawPath(using: .stroke)
    }
    
}
