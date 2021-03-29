//
//  ColoredLoadButton.swift
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

class ColoredLoadButton: NSButton {

    private let infoIconImage = #imageLiteral(resourceName: "info")
        
    var load: Int? {
        didSet {
            needsDisplay = true
        }
    }
    
    override var isFlipped: Bool {
        return false
    }
    
    override func viewWillDraw() {
        let loadValueString = load != nil ? "\(load!)%" : LocalizedString.unavailable
        toolTip = LocalizedString.load + " " + loadValueString
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let load = load else { return }
        
        // inner circle
        let icb = CGRect(x: 1.5, y: 1.5, width: bounds.width - 3, height: bounds.height - 3)
        context.setLineWidth(1.0)
        context.addEllipse(in: icb)
        context.setStrokeColor(NSColor.protonGreyOutOfFocus().cgColor)
        context.drawPath(using: .stroke)
        
        // outer circle segment
        let ocb = CGRect(x: 1, y: 1, width: bounds.width - 2, height: bounds.height - 2)
        let startAngle: CGFloat = .pi / 2
        let loadPortion = load > 15 ? load : 15
        let endAngle: CGFloat = (CGFloat(loadPortion) / 100) * (-2 * .pi) + .pi / 2
        context.setLineWidth(2.0)
        if load < 50 {
            context.setStrokeColor(NSColor.loadGreen().cgColor)
        } else if load < 90 {
            context.setStrokeColor(NSColor.loadYellow().cgColor)
        } else {
            context.setStrokeColor(NSColor.loadRed().cgColor)
        }
        context.addArc(center: CGPoint(x: (ocb.width / 2) + ocb.origin.x, y: (ocb.height / 2) + ocb.origin.y),
                       radius: ocb.width / 2,
                       startAngle: startAngle,
                       endAngle: endAngle,
                       clockwise: true)
        context.drawPath(using: .stroke)
        
        // info icon
        let infoSize = infoIconImage.size
        let desiredHeight = bounds.height / 2
        let desiredSize = CGSize(width: infoSize.width / (infoSize.height / desiredHeight), height: desiredHeight)
        var infoRect = CGRect(origin: CGPoint(x: bounds.width / 2 - desiredSize.width / 2, y: bounds.height / 2 - desiredHeight / 2),
                              size: desiredSize)
        if let image = infoIconImage.colored(NSColor.protonGreyOutOfFocus()).cgImage(forProposedRect: &infoRect, context: nil, hints: nil) {
            context.draw(image, in: infoRect)
        }
    }
    
    // MARK: - Accessibility
    
    override func isAccessibilityElement() -> Bool {
        return false
    }
    
    override func accessibilityChildren() -> [Any]? {
        return nil
    }
    
}
