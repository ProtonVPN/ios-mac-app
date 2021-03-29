//
//  TourNumberView.swift
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

class TourNumberView: NSView {

    private let shape = CAShapeLayer()
    
    private var insetPath: CGPath!
    private var expandedPath: CGPath!
    
    var expansionRadius: CGFloat = 4
    
    override func viewWillDraw() {
        wantsLayer = true
        
        shape.fillColor = NSColor.protonGreen().cgColor
        let insetRect = CGRect(x: bounds.minX + expansionRadius, y: bounds.minY + expansionRadius, width: bounds.width - 2 * expansionRadius, height: bounds.height - 2 * expansionRadius)
        insetPath = CGPath(ellipseIn: insetRect, transform: nil)
        expandedPath = CGPath(ellipseIn: bounds, transform: nil)
        shape.path = insetPath
        
        layer = shape
    }
    
    func animate() {
        let animation = CABasicAnimation(keyPath: "path")
        animation.toValue = expandedPath
        animation.duration = 0.15
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        animation.autoreverses = true
        shape.add(animation, forKey: animation.keyPath)
    }
}
