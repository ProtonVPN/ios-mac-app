//
//  FlagView.swift
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

class FlagView: NSView {
    
    var defaultColor: NSColor = .protonDarkGrey()

    var backgroundImage: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            PMLog.D("Flag view could not obtain drawing context.", level: .debug)
            return
        }
        
        fillBackground(context: context)
        
        if let image = backgroundImage {
            image.draw(in: bounds)
            addGradient(context: context)
        }
    }
    
    private func fillBackground(context: CGContext) {
        let path = CGMutablePath()
        path.addRect(bounds)
        
        context.setFillColor(defaultColor.cgColor)
        context.addPath(path)
        context.drawPath(using: .fill)
    }
    
    private func addGradient(context: CGContext) {
        let diagonal = NSGradient(starting: .clear, ending: .protonDarkGrey())
        diagonal?.draw(in: bounds, angle: 0)
        
        let curtain = NSGradient(starting: .clear, ending: .protonDarkGrey())
        curtain?.draw(in: bounds, angle: 270)
    }
}
