//
//  FeatureIcon.swift
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

class FeatureIcon: NSImageView {
        
    override var isFlipped: Bool {
        return false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // circle
        let icb = CGRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height - 1)
        context.setLineWidth(1.0)
        context.addEllipse(in: icb)
        context.setStrokeColor(NSColor.protonGreyOutOfFocus().cgColor)
        context.drawPath(using: .stroke)
        
        // draw image
        if let image = image {
            var imageRect: CGRect
            if image.size.height > image.size.width {
                let desiredHeight = 0.75 * bounds.height
                let desiredSize = CGSize(width: image.size.width / (image.size.height / desiredHeight), height: desiredHeight)
                imageRect = CGRect(origin: CGPoint(x: bounds.width / 2 - desiredSize.width / 2, y: bounds.height / 2 - desiredHeight / 2),
                                      size: desiredSize)
            } else {
                let desiredWidth = 0.75 * bounds.width
                let desiredSize = CGSize(width: desiredWidth, height: image.size.height / (image.size.width / desiredWidth))
                imageRect = CGRect(origin: CGPoint(x: bounds.width / 2 - desiredWidth / 2, y: bounds.height / 2 - desiredSize.height / 2),
                                      size: desiredSize)
            }
            if let image = image.colored(NSColor.protonGreyOutOfFocus()).cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
                context.draw(image, in: imageRect)
            }
        }
    }
}
