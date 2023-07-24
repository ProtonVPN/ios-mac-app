//
//  TourPreviousButton.swift
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
import Theme
import Ergonomics

class TourPreviousButton: HoverDetectionButton {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        wantsLayer = true
        layer?.borderWidth = 1.5
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        DarkAppearance {
            layer?.borderColor = self.cgColor(.border)
            layer?.backgroundColor = self.cgColor(.background)
        }
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let ah: CGFloat = 4.5 // arrowHeight
        let midX = bounds.midX + 0.5
        let midY = bounds.midY
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: midX, y: midY - ah))
        arrow.addLine(to: CGPoint(x: midX - ah, y: midY))
        arrow.addLine(to: CGPoint(x: midX, y: midY + ah))
        arrow.move(to: CGPoint(x: midX - ah, y: midY))
        arrow.addLine(to: CGPoint(x: midX + ah, y: midY))
        
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setStrokeColor(self.cgColor(.icon))
        context.addPath(arrow)
        context.drawPath(using: .stroke)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        trackingAreas.forEach {
            removeTrackingArea($0)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
}

extension TourPreviousButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .icon:
            return isHovered ? .normal : [.interactive, .weak]
        case .border:
            return isHovered ? .inverted : [.interactive, .weak]
        case .background:
            return .transparent
        default:
            break
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
