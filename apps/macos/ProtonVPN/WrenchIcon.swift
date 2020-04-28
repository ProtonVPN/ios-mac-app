//
//  WrenchIcon.swift
//  ProtonVPN - Created on 28.04.20.
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

class WrenchIcon: NSImageView {

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // circle
        let icb = CGRect(x: 1.5, y: 1.5, width: bounds.width - 3, height: bounds.height - 3)
        context.setLineWidth(1.0)
        context.addEllipse(in: icb)
        context.setStrokeColor(NSColor.protonGreyOutOfFocus().cgColor)
        context.drawPath(using: .stroke)

        // wrench icon
        let wrenchSize = #imageLiteral(resourceName: "wrench").size
        let desiredHeight = bounds.height / 2
        let desiredSize = CGSize(width: wrenchSize.width / (wrenchSize.height / desiredHeight), height: desiredHeight)
        var infoRect = CGRect(origin: CGPoint(x: bounds.width / 2 - desiredSize.width / 2, y: bounds.height / 2 - desiredHeight / 2),
                              size: desiredSize)
        if let image = #imageLiteral(resourceName: "wrench").colored(NSColor.protonGreyOutOfFocus()).cgImage(forProposedRect: &infoRect, context: nil, hints: nil) {
            context.draw(image, in: infoRect)
        }
    }
    
}
