//
//  LoadingAnimationView.swift
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

class LoadingAnimationView: NSView {

    let lineWidth: CGFloat = 2.0
    let speed: CGFloat = 2
    
    var shrinking = true
    var width: CGFloat!
    var timer: Timer?
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setup()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let icb = CGRect(x: lineWidth / 2, y: lineWidth / 2, width: bounds.width - lineWidth, height: bounds.height - lineWidth)
        
        context.setLineWidth(lineWidth)
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        
        let halfWidth = width / 2
        let halfHeight = icb.height / 2
        let centerX: CGFloat = icb.origin.x + halfHeight
        let centerY: CGFloat = icb.origin.y + halfHeight
        let circle1Bounds = CGRect(x: bounds.origin.x - halfWidth, y: bounds.origin.y - halfHeight, width: width, height: icb.height)
        context.translateBy(x: centerX, y: centerY)
        
        context.rotate(by: .pi / 4)
        context.addEllipse(in: circle1Bounds)
        
        context.rotate(by: -.pi / 2)
        context.addEllipse(in: circle1Bounds)
        
        context.drawPath(using: .stroke)
    }
    
    func animate(_ animate: Bool) {
        if animate {
            if timer == nil {
                timer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(redraw), userInfo: nil, repeats: true)
                redraw()
            }
        } else {
            if let timer = timer {
                timer.invalidate()
                self.timer = nil
            }
            width = bounds.width - lineWidth
        }
    }
    
    private func setup() {
        width = bounds.width - lineWidth
    }
    
    @objc private func redraw() {
        if width <= speed {
            shrinking = false
        } else if width >= bounds.width - lineWidth {
            shrinking = true
        }
        
        if shrinking {
            width -= speed
        } else {
            width += speed
        }
        
        needsDisplay = true
    }
}
