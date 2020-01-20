//
//  SidebarTabBarView.swift
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

class SidebarTabBarView: NSView {
    
    private let backgroundColor: CGColor = NSColor.protonDarkGrey().cgColor
    
    var activeTab: SidebarTab? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let activeTab = activeTab else {
            PMLog.D("Active tab not properly configured for sidebar tab bar view.", level: .debug)
            return
        }
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            PMLog.D("Unable to obtain context for drawing.", level: .debug)
            return
        }
        
        let leftRect = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width / 2, height: bounds.height)
        let rightRect = NSRect(x: bounds.origin.x + bounds.width / 2, y: bounds.origin.y, width: bounds.width / 2, height: bounds.height)
        
        drawBackground(context: context, rect: bounds)
        drawLeftSection(context: context, rect: leftRect, focused: activeTab == .countries)
        drawRightSection(context: context, rect: rightRect, focused: activeTab == .profiles)
    }
    
    private func drawBackground(context: CGContext, rect: CGRect) {
        let path = CGMutablePath()
        path.addRect(rect)
        
        context.setFillColor(backgroundColor)
        context.addPath(path)
        context.fillPath()
    }
    
    private func drawLeftSection(context: CGContext, rect: CGRect, focused: Bool) {
        var path = CGMutablePath()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 5, y: rect.maxY - 20), control: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 15))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        var color = getColor(forFocus: focused)
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
        
        if !focused {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY + 15))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 25, y: rect.minY), control: CGPoint(x: rect.maxX - 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 15))
            
            color = getColor(forFocus: !focused)
            context.setFillColor(color)
            context.addPath(path)
            context.fillPath()
        }
    }
    
    private func drawRightSection(context: CGContext, rect: CGRect, focused: Bool) {
        var path = CGMutablePath()

        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 5, y: rect.maxY - 20), control: CGPoint(x: rect.minX + 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 15))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        var color = getColor(forFocus: focused)
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
        
        if !focused {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + 15))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 25, y: rect.minY), control: CGPoint(x: rect.minX + 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 15))
            
            color = getColor(forFocus: !focused)
            context.setFillColor(color)
            context.addPath(path)
            context.fillPath()
        }
    }
    
    private func getColor(forFocus present: Bool) -> CGColor {
        return present ? NSColor.protonGrey().cgColor : NSColor.protonDarkGreyShade().cgColor
    }
}
