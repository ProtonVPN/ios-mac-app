//
//  StatusBarAppConnectButton.swift
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

class LargeDropdownButton: HoverDetectionButton {
    
    var isConnected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var dropDownExpanded: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        configureButton()
    }
    
    private func configureButton() {
        wantsLayer = true
        isBordered = false
        title = ""
    }
}

// swiftlint:disable operator_usage_whitespace
class StatusBarAppConnectButton: LargeDropdownButton {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let lw: CGFloat = 2
        let ib: CGRect
        if isConnected {
            ib = NSRect(x: bounds.origin.x + lw/2, y: bounds.origin.y + lw/2, width: bounds.width - lw, height: bounds.height - lw)
            context.setStrokeColor(isHovered ? NSColor.protonRed().cgColor : NSColor.protonWhite().cgColor)
            context.setFillColor(NSColor.clear.cgColor)
        } else {
            ib = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width - lw/2, height: bounds.height)
            context.setStrokeColor(NSColor.clear.cgColor)
            context.setFillColor(isHovered ? NSColor.protonGreenShade().cgColor : NSColor.protonGreen().cgColor)
        }
        
        context.setLineWidth(lw)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: ib.maxX, y: ib.maxY))
        
        if dropDownExpanded {
            path.addLine(to: CGPoint(x: ib.minX, y: ib.maxY))
            path.addArc(center: CGPoint(x: ib.minX + ib.height/2, y: ib.minY + ib.height/2), radius: ib.height/2, startAngle: .pi, endAngle: .pi*3/2, clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: ib.minX + ib.height/2, y: ib.maxY))
            path.addArc(center: CGPoint(x: ib.minX + ib.height/2, y: ib.minY + ib.height/2), radius: ib.height/2, startAngle: .pi/2, endAngle: .pi*3/2, clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: ib.maxX, y: ib.minY))
        path.closeSubpath()
        
        context.addPath(path)
        context.drawPath(using: .fillStroke)
        
        let buttonTitle: NSAttributedString
        if isConnected {
            let accentColor: NSColor = isHovered ? .protonRed() : .protonWhite()
            buttonTitle = LocalizedString.disconnect.attributed(withColor: accentColor, fontSize: 14)
        } else {
            let accentColor: NSColor = .protonWhite()
            buttonTitle = LocalizedString.quickConnect.capitalized.attributed(withColor: accentColor, fontSize: 14)
        }
        let textHeight = buttonTitle.size().height
        buttonTitle.draw(in: CGRect(x: bounds.height/2, y: (bounds.height - textHeight) / 2, width: bounds.width - bounds.height/2, height: textHeight))
    }
}
// swiftlint:enable operator_usage_whitespace

// swiftlint:disable function_body_length operator_usage_whitespace
class StatusBarAppProfileDropdownButton: LargeDropdownButton {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if isConnected {
            if isHovered {
                context.setStrokeColor(NSColor.protonRed().cgColor)
            } else {
                context.setStrokeColor(NSColor.protonWhite().cgColor)
            }
        } else {
            context.setStrokeColor(NSColor.clear.cgColor)
        }
        
        let lw: CGFloat = 2
        let ib: CGRect
        if isConnected {
            ib = NSRect(x: bounds.origin.x - lw/2, y: bounds.origin.y + lw/2, width: bounds.width - lw/2, height: bounds.height - lw)
            context.setStrokeColor(isHovered ? NSColor.protonGreyOutOfFocus().cgColor : NSColor.protonWhite().cgColor)
            context.setFillColor(NSColor.clear.cgColor)
        } else {
            ib = NSRect(x: bounds.origin.x + lw/2, y: bounds.origin.y, width: bounds.width - lw/2, height: bounds.height)
            context.setStrokeColor(NSColor.clear.cgColor)
            context.setFillColor(isHovered ? NSColor.protonGreenShade().cgColor : NSColor.protonGreen().cgColor)
        }
        
        context.setLineWidth(lw)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: ib.minX, y: ib.minY))
        path.addLine(to: CGPoint(x: ib.maxX - ib.height/2, y: ib.minY))
        
        if dropDownExpanded {
            path.addArc(center: CGPoint(x: ib.maxX - ib.height/2, y: ib.maxY - ib.height/2), radius: ib.height/2, startAngle: .pi*3/2, endAngle: 0, clockwise: false)
            path.addLine(to: CGPoint(x: ib.maxX, y: ib.maxY))
        } else {
            path.addArc(center: CGPoint(x: ib.maxX - ib.height/2, y: ib.maxY - ib.height/2), radius: ib.height/2, startAngle: .pi*3/2, endAngle: .pi/2, clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: ib.minX, y: ib.maxY))
        path.closeSubpath()
        
        let ah: CGFloat = dropDownExpanded ? -4 : 4 // arrowHeight
        let midX: CGFloat = bounds.midX - 2
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: midX - ah, y: bounds.midY - ah/2))
        arrow.addLine(to: CGPoint(x: midX, y: bounds.midY + ah/2))
        arrow.addLine(to: CGPoint(x: midX + ah, y: bounds.midY - ah/2))
        
        context.addPath(path)
        context.drawPath(using: .fillStroke)
        
        context.setLineWidth(1)
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        context.addPath(arrow)
        context.drawPath(using: .stroke)
    }
}
// swiftlint:enable function_body_length operator_usage_whitespace
