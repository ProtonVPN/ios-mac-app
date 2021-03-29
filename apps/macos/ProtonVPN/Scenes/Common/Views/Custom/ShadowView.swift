//
//  ShadowView.swift
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

class ShadowView: NSView {

    private var darkness = NSColor(red: 0, green: 0, blue: 0, alpha: 0.25)
    private var gradientHeight: CGFloat!
    
    override var isFlipped: Bool {
        return true
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        gradientHeight = bounds.height
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let colors = [darkness.cgColor, NSColor.clear.cgColor]
        let colorPoints: [CGFloat] = [0, 1]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: colorPoints)!
        
        context.drawLinearGradient(gradient, start: bounds.origin, end: CGPoint(x: 0, y: gradientHeight), options: [])
    }
    
    func shadow(for height: CGFloat) {
        darkness = NSColor(red: 0, green: 0, blue: 0, alpha: height < bounds.height ? (0.25 * height) / bounds.height : 0.25)
        needsDisplay = true
    }
}
