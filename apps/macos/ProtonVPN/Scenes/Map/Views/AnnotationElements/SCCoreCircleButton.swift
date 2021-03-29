//
//  SCCoreCircleButton.swift
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

class SCCoreCircleButton: HoverDetectionButtonAdvanced {
    
    enum ButtonState {
        case idle
        case active
    }
    
    private let viewState: ButtonState
    
    override var isHighlighted: Bool {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(frame frameRect: NSRect, state: ButtonState) {
        self.viewState = state
        super.init(frame: frameRect)
        
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .imageOnly
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        switch viewState {
        case .idle:
            context.setStrokeColor(isHovered ? stateColor(for: NSColor.protonLightGreen()) : stateColor(for: NSColor.protonGreen()))
            context.setFillColor(stateColor(for: NSColor.protonMapBackgroundGrey()))
        case .active:
            context.setStrokeColor(stateColor(for: NSColor.protonGreen()))
            context.setFillColor(stateColor(for: NSColor.protonWhite()))
        }
        
        let lineWidth: CGFloat = 2.0
        let innerFrame = CGRect(x: lineWidth / 2, y: lineWidth / 2, width: bounds.width - lineWidth, height: bounds.height - lineWidth)
        context.setLineWidth(lineWidth)
        context.addEllipse(in: innerFrame)
        
        context.drawPath(using: .fillStroke)
    }
    
    private func stateColor(for color: NSColor) -> CGColor {
        if isHighlighted, let correctColorSpaceColor = color.usingColorSpace(NSColorSpace.deviceRGB) {
            return NSColor(red: correctColorSpaceColor.redComponent * 0.5,
                           green: correctColorSpaceColor.greenComponent * 0.5,
                           blue: correctColorSpaceColor.blueComponent * 0.5,
                           alpha: correctColorSpaceColor.alphaComponent)
                .cgColor
        } else {
            return color.cgColor
        }
    }
}
