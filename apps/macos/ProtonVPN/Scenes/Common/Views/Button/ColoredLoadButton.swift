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
    private let infoIconImage = AppTheme.Icon.infoCircle
        
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
        
        // outer circle segment
        let ocb = CGRect(x: 1, y: 1, width: bounds.width - 2, height: bounds.height - 2)
        let startAngle: CGFloat = .pi / 2
        let loadPortion = load > 15 ? load : 15
        let endAngle: CGFloat = (CGFloat(loadPortion) / 100) * (-2 * .pi) + .pi / 2
        context.setLineWidth(2.0)
        context.setStrokeColor(self.cgColor(.border))
        context.addArc(center: CGPoint(x: (ocb.width / 2) + ocb.origin.x, y: (ocb.height / 2) + ocb.origin.y),
                       radius: ocb.width / 2,
                       startAngle: startAngle,
                       endAngle: endAngle,
                       clockwise: true)
        context.drawPath(using: .stroke)
        
        // info icon
        let desiredSize = CGSize(width: bounds.width, height: bounds.height)
        var infoRect = CGRect(origin: CGPoint(x: 0, y: 0), size: desiredSize)

        if let image = self.colorImage(infoIconImage).cgImage(forProposedRect: &infoRect, context: nil, hints: nil) {
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

extension ColoredLoadButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .icon:
            return .weak
        case .border:
            guard let load = load else { return .normal }
            
            if load < 76 {
                return .success
            } else if load < 91 {
                return .warning
            } else {
                return .danger
            }
        default:
            break
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
