//
//  LoadIcon.swift
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

class LoadIcon: NSView {
    
    var load: Int? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        let loadValueString = load != nil ? "\(load!)%" : LocalizedString.unavailable
        toolTip = LocalizedString.load + " " + loadValueString
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let load = load else {
            return
        }
        
        // inner circle
        let icb = CGRect(x: 2.5, y: 2.5, width: bounds.width - 5, height: bounds.height - 5)
        context.setLineWidth(1.0)
        context.addEllipse(in: icb)
        context.setStrokeColor(NSColor.protonWhite().cgColor)
        context.drawPath(using: .stroke)
        
        // outer circle segment
        let ocb = CGRect(x: 1.5, y: 1.5, width: bounds.width - 3, height: bounds.height - 3)
        let startAngle: CGFloat = .pi / 2
        let loadPortion = load > 15 ? load : 15
        let endAngle: CGFloat = (CGFloat(loadPortion) / 100) * (-2 * .pi) + .pi / 2
        context.setLineWidth(3.0)
        context.addArc(center: CGPoint(x: (ocb.width / 2) + ocb.origin.x, y: (ocb.height / 2) + ocb.origin.y),
                       radius: ocb.width / 2,
                   startAngle: startAngle,
                     endAngle: endAngle,
                    clockwise: true)
        context.drawPath(using: .stroke)
        
        // load text
        let ltb = CGRect(x: icb.origin.x, y: icb.origin.y + icb.height / 6, width: icb.width, height: (icb.height / 6) * (6 - 2))
        let path = CGMutablePath()
        path.addRect(ltb)
        
        var fontSize: CGFloat = 12
        let attrString = NSMutableAttributedString(string: "\(load)", attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: fontSize, weight: .bold)])
        let textRange = NSRange(location: 0, length: attrString.string.count)
        
        // find the largest font that will fit inside our desired text area
        while attrString.size().height > ltb.height {
            guard fontSize > 0 else { break }
            fontSize -= 1
            attrString.setAttributes([NSAttributedString.Key.font: NSFont.systemFont(ofSize: fontSize, weight: .bold)], range: textRange)
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        let attributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                          NSAttributedString.Key.foregroundColor: NSColor.protonWhite(),
                          NSAttributedString.Key.paragraphStyle: paragraphStyle,
                          NSAttributedString.Key.baselineOffset: NSNumber(value: -0.4)]
        attrString.setAttributes(attributes, range: textRange)
        
        let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), path, nil)
        CTFrameDraw(frame, context)
    }
}
