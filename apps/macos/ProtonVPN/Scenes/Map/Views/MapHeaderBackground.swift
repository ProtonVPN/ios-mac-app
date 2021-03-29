//
//  MapHeaderBackground.swift
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

class MapHeaderBackground: NSView {
    
    private let upperBorderRadius: CGFloat = 140
    private let lowerBorderRadius: CGFloat = 75
    private let headerHeight: CGFloat = 55
    
    private let outterCircleRadius: CGFloat = 20
    private let innerCircleRadius: CGFloat = 15
    
    let width: CGFloat
    let backgroundColor: CGColor = NSColor.protonGreyShade().cgColor
    
    var isConnected: Bool? {
        didSet {
            needsDisplay = true
        }
    }
    
    var path = CGMutablePath()
    var outter = CGMutablePath()
    var clicked: (() -> Void)?

    required init?(coder decoder: NSCoder) {
        width = upperBorderRadius * 2
        super.init(coder: decoder)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if path.contains(point) || outter.contains(point) {
            return super.hitTest(point)
        } else {
            return nil
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let pointInView = convert(event.locationInWindow, from: nil)
        if path.contains(pointInView) || outter.contains(pointInView) {
            clicked?()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        // prevents dragging in obscured views (map view)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let isConnected = isConnected else {
            PMLog.D("Unable to obtain context for drawing.", level: .debug)
            return
        }
        
        let delta = upperBorderRadius - lowerBorderRadius
        path = CGMutablePath()
        let start = CGPoint(x: bounds.width / 2 - upperBorderRadius, y: bounds.maxY)
        
        // Left part of the view
        path.move(to: start)
        
        var controlPoint = CGPoint(x: bounds.width / 2 - lowerBorderRadius - delta * 0.75, y: bounds.maxY)
        var endPoint = CGPoint(x: bounds.width / 2 - lowerBorderRadius - delta * 0.5, y: bounds.maxY - headerHeight / 2)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        controlPoint = CGPoint(x: bounds.width / 2 - lowerBorderRadius - delta * 0.25, y: bounds.maxY - headerHeight)
        endPoint = CGPoint(x: bounds.width / 2 - lowerBorderRadius, y: bounds.maxY - headerHeight)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        // Right part of the view
        path.addLine(to: CGPoint(x: bounds.width / 2 + lowerBorderRadius, y: bounds.maxY - headerHeight))
        
        controlPoint = CGPoint(x: bounds.width / 2 + lowerBorderRadius + delta * 0.25, y: bounds.maxY - headerHeight)
        endPoint = CGPoint(x: bounds.width / 2 + lowerBorderRadius + 0.5 * delta, y: bounds.maxY - headerHeight / 2)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        controlPoint = CGPoint(x: bounds.width / 2 + lowerBorderRadius + delta * 0.75, y: bounds.maxY)
        endPoint = CGPoint(x: bounds.width / 2 + upperBorderRadius, y: bounds.maxY)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        path.addLine(to: start)
        
        context.addPath(path)
        context.setFillColor(backgroundColor)
        context.drawPath(using: .fill)
        
        outter = CGMutablePath()
        var circleOrigin = CGPoint(x: bounds.width / 2 - outterCircleRadius, y: bounds.maxY - headerHeight - outterCircleRadius)
        var circleBounds = CGSize(width: 2 * outterCircleRadius, height: 2 * outterCircleRadius)
        var circleRect = CGRect(origin: circleOrigin, size: circleBounds)
        outter.addEllipse(in: circleRect)
        
        context.addPath(outter)
        context.drawPath(using: .fill)
        
        let inner = CGMutablePath()
        circleOrigin = CGPoint(x: bounds.width / 2 - innerCircleRadius, y: bounds.maxY - headerHeight - innerCircleRadius)
        circleBounds = CGSize(width: 2 * innerCircleRadius, height: 2 * innerCircleRadius)
        circleRect = CGRect(origin: circleOrigin, size: circleBounds)
        inner.addEllipse(in: circleRect)
        
        let innerColor = colorForState(connected: isConnected)
        context.addPath(inner)
        context.setFillColor(innerColor)
        context.drawPath(using: .fill)
    }
    
    private func colorForState(connected: Bool) -> CGColor {
        return connected ? NSColor.protonGreen().cgColor : NSColor.protonLightGrey().cgColor
    }
}
