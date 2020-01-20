//
//  TabBarView.swift
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

class TabBarView: NSView {
    
    private let minimumTabWidth: CGFloat = 150
    private let minimumTabHeight: CGFloat = 40

    var tabWidth: CGFloat?
    var tabHeight: CGFloat?
    var tabCount: Int?
    
    var focusedTabIndex: Int? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            PMLog.D("Unable to obtain drawing context for tab bar view", level: .debug)
            return
        }
        
        guard let tabCount = tabCount, tabCount >= 1 else {
            PMLog.D("Tab count not properly set in tab bar view", level: .debug)
            return
        }
        
        guard let focusedTabIndex = focusedTabIndex, focusedTabIndex >= 0, focusedTabIndex < tabCount else {
            PMLog.D("Focused tab index not properly set in tab bar view", level: .debug)
            return
        }
        
        guard let tabWidth = tabWidth, tabWidth >= minimumTabWidth else {
            PMLog.D("Tab width property does not satisfy necessary requirements", level: .debug)
            return
        }
        
        guard let tabHeight = tabHeight, tabHeight >= minimumTabHeight else {
            PMLog.D("Tab height property does not satisfy necessary requirements", level: .debug)
            return
        }
        
        guard bounds.width > CGFloat(tabCount) * tabWidth else {
            PMLog.D("Unable to draw tab bar under given constraints: \(bounds)", level: .debug)
            return
        }
        
        for i in 0..<tabCount {
            let rect = NSRect(x: bounds.origin.x + CGFloat(i) * tabWidth, y: bounds.origin.y, width: tabWidth, height: tabHeight)
            if i == 0 {
                drawLeftmostSection(context: context, rect: rect, sectionIndex: i)
            } else {
                drawSection(context: context, rect: rect, sectionIndex: i)
            }
        }
    }
    
    private func drawLeftmostSection(context: CGContext, rect: CGRect, sectionIndex index: Int) {
        var path = CGMutablePath()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY / 2), control: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        
        if !isRightNeighbourPresent(forIndex: index) {
            path.addQuadCurve(to: CGPoint(x: rect.maxX + 25, y: rect.minY), control: CGPoint(x: rect.maxX + 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        var color = getColor(forFocus: isFocused(tabIndex: index))
        context.setFillColor(color)
        context.addPath(path)
        context.drawPath(using: .fill)
        
        if isRightNeighbourFocused(forIndex: index) {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 25, y: rect.minY), control: CGPoint(x: rect.maxX - 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            
            color = getColor(forFocus: true)
            context.setFillColor(color)
            context.addPath(path)
            context.drawPath(using: .fill)
        }
    }
    
    private func drawSection(context: CGContext, rect: CGRect, sectionIndex index: Int) {
        var path = CGMutablePath()
        
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        if !isRightNeighbourPresent(forIndex: index) {
            path.addLine(to: CGPoint(x: rect.maxX + 25, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height / 2), control: CGPoint(x: rect.maxX + 5, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.height / 2))
        }
        
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 35, y: rect.maxY), control: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 35, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY / 2), control: CGPoint(x: rect.minX + 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        var color = getColor(forFocus: isFocused(tabIndex: index))
        context.setFillColor(color)
        context.addPath(path)
        context.drawPath(using: .fill)
        
        if isLeftNeighbourFocused(forIndex: index) {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY / 2))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 25, y: rect.minY), control: CGPoint(x: rect.minX + 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY / 2))
            
            color = getColor(forFocus: true)
            context.setFillColor(color)
            context.addPath(path)
            context.drawPath(using: .fill)
        } else if isRightNeighbourFocused(forIndex: index) {
            path = CGMutablePath()
            
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 25, y: rect.minY), control: CGPoint(x: rect.maxX - 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
            
            color = getColor(forFocus: true)
            context.setFillColor(color)
            context.addPath(path)
            context.drawPath(using: .fill)
        }
    }
    
    private func getColor(forFocus present: Bool) -> CGColor {
        return present ? NSColor.protonGrey().cgColor : NSColor.protonGreyShade().cgColor
    }
    
    private func isFocused(tabIndex index: Int) -> Bool {
        return focusedTabIndex == index
    }
    
    private func isLeftNeighbourFocused(forIndex index: Int) -> Bool {
        return focusedTabIndex == index - 1
    }
    
    private func isRightNeighbourPresent(forIndex index: Int) -> Bool {
        return tabCount != index + 1
    }
    
    private func isRightNeighbourFocused(forIndex index: Int) -> Bool {
        return focusedTabIndex == index + 1
    }
}
