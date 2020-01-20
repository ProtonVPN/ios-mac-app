//
//  ProfilesTabBarView.swift
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

class ProfilesTabBarView: NSView {

    private let tabWidth: CGFloat = 200
    private let tabHeight: CGFloat = 40
    
    var activeTab: ProfilesTab? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext, let activeTab = activeTab else {
            return
        }
        
        if bounds.width < 2.5 * tabWidth {
            PMLog.D("Unable to draw tab bar under given constraints: \(bounds)", level: .debug)
            return
        }
        
        let leftRect = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: tabWidth, height: tabHeight)
        let rightRect = NSRect(x: bounds.origin.x + tabWidth, y: bounds.origin.y, width: tabWidth, height: tabHeight)
        
        drawLeftSection(context: context, rect: leftRect, focused: activeTab == .overview)
        drawRightSection(context: context, rect: rightRect, focused: activeTab != .overview)
    }
    
    private func drawLeftSection(context: CGContext, rect: CGRect, focused: Bool) {
        var path = CGMutablePath()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY / 2), control: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        var color = getColor(forFocus: focused)
        context.setFillColor(color)
        context.addPath(path)
        context.drawPath(using: .fill)
        
        if !focused {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 25, y: rect.minY), control: CGPoint(x: rect.maxX - 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            
            color = getColor(forFocus: !focused)
            context.setFillColor(color)
            context.addPath(path)
            context.drawPath(using: .fill)
        }
    }
    
    private func drawRightSection(context: CGContext, rect: CGRect, focused: Bool) {
        var path = CGMutablePath()
        
        path.move(to: CGPoint(x: rect.maxX + 25, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height / 2), control: CGPoint(x: rect.maxX + 5, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 35, y: rect.maxY), control: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY / 2), control: CGPoint(x: rect.minX + 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX + 25, y: rect.minY))
        
        var color = getColor(forFocus: focused)
        context.setFillColor(color)
        context.addPath(path)
        context.drawPath(using: .fill)
        
        if !focused {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY / 2))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 25, y: rect.minY), control: CGPoint(x: rect.minX + 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY / 2))
            
            color = getColor(forFocus: !focused)
            context.setFillColor(color)
            context.addPath(path)
            context.drawPath(using: .fill)
        }
    }
    
    // MARK: - Colors
    private func getColor(forFocus present: Bool) -> CGColor {
        return present ? NSColor.protonGrey().cgColor : NSColor.protonGreyShade().cgColor
    }
}
