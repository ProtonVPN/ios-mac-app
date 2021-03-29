//
//  PVPNTextField.swift
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

class PVPNHyperlinkTextField: HoverDetectionButton {
    
    override var title: String {
        didSet {
            attributedTitle = title.attributed(withColor: .protonWhite(), fontSize: 10)
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        context.move(to: CGPoint(x: bounds.origin.x + (bounds.size.width - attributedTitle.size().width) / 2, y: bounds.origin.y + bounds.size.height - 0.5))
        context.addLine(to: CGPoint(x: bounds.origin.x + attributedTitle.size().width + (bounds.size.width - attributedTitle.size().width) / 2, y: bounds.origin.y + bounds.size.height - 0.5))
        context.drawPath(using: .stroke)
    }
}
