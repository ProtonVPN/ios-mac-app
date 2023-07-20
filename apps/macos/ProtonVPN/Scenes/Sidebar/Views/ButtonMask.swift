//
//  ButtonMask.swift
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
import Ergonomics

class ButtonMask: NSView {
    var drawBorder: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    var maskColor: CGColor = .clear {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        DarkAppearance {
            self.maskColor = .cgColor(.background, .weak)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawMask(context: context)
        
        if drawBorder {
            drawBorder(context: context)
        }
    }

    private func drawMask(context: CGContext) {
        context.setLineWidth(0.0)
        context.setFillColor(maskColor)
        context.setShouldAntialias(true)
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.origin.x + bounds.height / 2, y: bounds.origin.y))
            path.addArc(center: CGPoint(x: bounds.origin.x + bounds.height / 2, y: bounds.origin.y + bounds.height / 2),
                        radius: bounds.height / 2,
                        startAngle: .pi / 2,
                        endAngle: (3 * .pi) / 2,
                        clockwise: false)
            path.addLine(to: CGPoint(x: bounds.origin.x, y: bounds.origin.y))
            path.addLine(to: CGPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.height))
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.height / 2, y: bounds.origin.y + bounds.height))
            context.addPath(path)
        }

        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.origin.x + bounds.width - bounds.height / 2, y: bounds.origin.y))
            path.addArc(center: CGPoint(x: bounds.origin.x + bounds.width - bounds.height / 2, y: bounds.origin.y + bounds.height / 2),
                        radius: bounds.height / 2,
                        startAngle: .pi / 2,
                        endAngle: (3 * .pi) / 2,
                        clockwise: true)
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.width, y: bounds.origin.y))
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.width, y: bounds.origin.y + bounds.height))
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.width - bounds.height / 2, y: bounds.origin.y + bounds.height))
            context.addPath(path)
        }

        context.drawPath(using: .eoFill)
    }

    private func drawBorder(context: CGContext) {
        context.setLineWidth(1.5)
        context.setStrokeColor(.cgColor(.border, .strong))
        do {
            // borders along arcs
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: bounds.origin.x + bounds.height / 2, y: bounds.origin.y + bounds.height / 2),
                        radius: bounds.height / 2 - 0.5,
                        startAngle: .pi / 2,
                        endAngle: (3 * .pi) / 2,
                        clockwise: false)
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.width - bounds.height / 2, y: bounds.origin.y + 0.5))
            path.addArc(center: CGPoint(x: bounds.origin.x + bounds.width - bounds.height / 2, y: bounds.origin.y + bounds.height / 2),
                        radius: bounds.height / 2 - 0.5,
                        startAngle: (3 * .pi) / 2,
                        endAngle: .pi / 2,
                        clockwise: false)
            path.addLine(to: CGPoint(x: bounds.origin.x + bounds.height / 2, y: bounds.origin.y + bounds.height - 0.5))
            context.addPath(path)
        }
        context.drawPath(using: .stroke)
    }
}
