//
//  SCExitCountryAnnotationView.swift
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
import MapKit
import vpncore

class SCExitCountryAnnotationView: MKAnnotationView {
    
    private let buttonHeight: CGFloat = 30
    private let buttonWidth: CGFloat
    private let buttonFrame: CGRect
    
    private let triangleWidth: CGFloat = 17
    private let triangleHeight: CGFloat = 14
    
    private var triangleFrame: CGRect = CGRect()
    
    private var path = CGMutablePath()
    
    let viewModel: SCExitCountryAnnotationViewModel
    
    var _tag = -1
    override var tag: Int {
        get {
            return _tag
        }
        set {
            _tag = newValue
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(viewModel: SCExitCountryAnnotationViewModel, reuseIdentifier: String?) {
        self.viewModel = viewModel
        buttonWidth = viewModel.buttonWidth
        
        buttonFrame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight * CGFloat(viewModel.servers.count + 1))
        
        super.init(annotation: nil, reuseIdentifier: reuseIdentifier)
        
        viewModel.viewStateChange = { [weak self] in
            guard let `self` = self else { return }
            self.setupAnnotationView()
            self.needsDisplay = true
        }
        
        setupAnnotationView()
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin - NSPoint(x: buttonWidth / 2, y: 0))
    }
    
    // swiftlint:disable function_body_length operator_usage_whitespace
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if viewModel.isConnected {
            context.setStrokeColor(stateColor(for: viewModel.state == .hovered ? NSColor.protonWhite() : NSColor.protonGreen()))
            context.setFillColor(stateColor(for: NSColor.protonGreen()))
        } else {
            switch viewModel.state {
            case .idle:
                context.setStrokeColor(stateColor(for: (viewModel.available ? NSColor.protonGreen() : NSColor.protonGreyButtonBackground())))
            case .hovered:
                context.setStrokeColor(stateColor(for: (viewModel.available ? NSColor.protonWhite() : NSColor.protonGreyButtonBackground())))
            }
            context.setFillColor(stateColor(for: NSColor.protonGreyShade()))
        }
        
        let lineWidth: CGFloat = 1.0
        path = CGMutablePath()
        
        // triangle
        let itf/*innerTriangleFrame*/ = CGRect(x: triangleFrame.origin.x + lineWidth/2, y: triangleFrame.origin.y + lineWidth/2, width: triangleFrame.width - lineWidth, height: triangleFrame.height - lineWidth)
        context.setLineWidth(lineWidth)
        path.move(to: CGPoint(x: itf.origin.x, y: itf.origin.y))
        path.addLine(to: CGPoint(x: itf.origin.x + itf.width / 2, y: itf.origin.y + itf.height))
        path.addLine(to: CGPoint(x: itf.origin.x + itf.width, y: itf.origin.y))
        
        if viewModel.state == .hovered {
            // button
            let ibf/*innerButtonFrame*/ = CGRect(x: lineWidth/2, y: lineWidth/2, width: buttonWidth - lineWidth, height: buttonHeight * CGFloat(viewModel.servers.count + 1))
            path.addLine(to: CGPoint(x: ibf.maxX - buttonHeight/2, y: ibf.maxY))
            path.addArc(center: CGPoint(x: ibf.maxX - buttonHeight/2, y: ibf.maxY - buttonHeight/2), radius: buttonHeight/2, startAngle: .pi/2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: ibf.maxX, y: ibf.minY + buttonHeight/2))
            path.addArc(center: CGPoint(x: ibf.maxX - buttonHeight/2, y: ibf.minY + buttonHeight/2), radius: buttonHeight/2, startAngle: 0, endAngle: .pi*3/2, clockwise: true)
            path.addLine(to: CGPoint(x: ibf.minX + buttonHeight/2, y: ibf.minY))
            path.addArc(center: CGPoint(x: ibf.minX + buttonHeight/2, y: ibf.minY + buttonHeight/2), radius: buttonHeight/2, startAngle: .pi*3/2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: ibf.minX, y: ibf.maxY - buttonHeight/2))
            path.addArc(center: CGPoint(x: ibf.minX + buttonHeight/2, y: ibf.maxY - buttonHeight/2), radius: buttonHeight/2, startAngle: .pi, endAngle: .pi/2, clockwise: true)
        }
        
        // close shape (either top of triangle or last section of button)
        path.closeSubpath()
        context.addPath(path)
        context.drawPath(using: .fillStroke)
        
        if viewModel.state == .hovered {
            // server titles
            guard let window = window else { return }
            let mousePoint = window.mouseLocationOutsideOfEventStream
            let pointInView = self.convert(mousePoint, from: nil)
            viewModel.servers.enumerated().forEach { index, _ in
                let itemFrame = CGRect(x: buttonFrame.origin.x, y: buttonFrame.origin.y + buttonHeight * CGFloat(index), width: buttonWidth, height: buttonHeight)
                let attributedTitle: NSAttributedString
                
                if itemFrame.contains(pointInView) && self.viewModel.state == .hovered {
                    attributedTitle = viewModel.attributedConnectTitle(for: index)
                } else {
                    attributedTitle = viewModel.attributedServer(for: index)
                }
                
                let textHeight = attributedTitle.size().height
                attributedTitle.draw(in: CGRect(x: 0, y: buttonHeight * CGFloat(index) + ((buttonHeight - textHeight) / 2), width: buttonWidth, height: textHeight))
            }
            
            // country title
            let attributedTitle = viewModel.attributedCountry
            let textHeight = attributedTitle.size().height
            attributedTitle.draw(in: CGRect(x: 0, y: buttonHeight * CGFloat(viewModel.servers.count) + ((buttonHeight - textHeight) / 2), width: buttonWidth, height: textHeight))
        }
    }
    // swiftlint:enable function_body_length operator_usage_whitespace
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let pointInView = point - frame.origin
        let hitTestRect = viewModel.state == .idle ? triangleFrame : bounds
        
        return hitTestRect.contains(pointInView) ? self : nil
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseInside(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        mouseInside(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard viewModel.state == .hovered else { return }
        let pointInView = convert(event.locationInWindow, from: nil)
        viewModel.servers.enumerated().forEach { index, _ in
            let itemFrame = CGRect(x: buttonFrame.origin.x, y: buttonFrame.origin.y + buttonHeight * CGFloat(index), width: buttonWidth, height: buttonHeight)
            if itemFrame.contains(pointInView) {
                viewModel.serverConnectAction(forRow: index)
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if viewModel.state == .hovered {
            viewModel.uiStateUpdate(.idle)
        }
    }
    
    override func resetCursorRects() {
        guard viewModel.state == .hovered else { return }
        addCursorRect(CGRect(origin: buttonFrame.origin, size: CGSize(width: buttonFrame.width, height: buttonFrame.height - buttonHeight)), cursor: .pointingHand)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: viewModel.state == .idle ? triangleFrame : bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        DispatchQueue.main.async { [unowned self] in
            if let window = self.window {
                let mousePoint = window.mouseLocationOutsideOfEventStream
                let pointInView = self.convert(mousePoint, from: nil)
                if !self.bounds.contains(pointInView) && self.viewModel.state == .hovered {
                    self.viewModel.uiStateUpdate(.idle)
                }
            }
        }
    }
    
    // MARK: - Private functions
    private func mouseInside(with event: NSEvent) {
        // hit test before hovering incase a view is obscuring this one already
        guard let hitView = window?.contentView?.hitTest(event.locationInWindow) else { return }
        
        if hitView === self {
            let pointInView = convert(event.locationInWindow, from: nil)
            if path.contains(pointInView) {
                if viewModel.state == .idle {
                    viewModel.uiStateUpdate(.hovered)
                }
            } else if viewModel.state == .hovered {
                viewModel.uiStateUpdate(.idle)
            }
        }
        
        if viewModel.state == .hovered {
            resetCursorRects()
            needsDisplay = true
        }
    }
    
    private func setupAnnotationView() {
        setSelection()
        setupFrame()
    }
    
    private func setSelection() {
        if viewModel.state == .idle {
            setSelected(false, animated: false)
        } else {
            setSelected(true, animated: true)
        }
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
    
    private func setupFrame() {
        let height: CGFloat
        switch viewModel.state {
        case .idle:
            height = triangleHeight
            tag = -1 // default view tag
        case .hovered:
            height = triangleHeight + CGFloat(1 + viewModel.servers.count) * buttonHeight
            
            // brings this view to the forefront of the superview's subviews
            if let parentView = superview {
                tag = 100 // arbitrary
                parentView.sortSubviews({ (view1, view2, _) -> ComparisonResult in
                    if view1.tag > view2.tag {
                        return .orderedDescending
                    } else if view1.tag < view2.tag {
                        return .orderedAscending
                    } else {
                        return .orderedSame
                    }
                }, context: nil)
            }
        }
        
        setFrameSize(NSSize(width: buttonWidth, height: height))
        centerOffset = NSPoint(x: 0, y: -frame.size.height / 2)
        setTriangleFrame()
    }
    
    private func setTriangleFrame() {
        let triangleOrigin = NSPoint(x: (buttonWidth - triangleWidth) / CGFloat(2), y: bounds.height - triangleHeight)
        let triangleSize = NSSize(width: triangleWidth, height: triangleHeight)
        triangleFrame = CGRect(origin: triangleOrigin, size: triangleSize)
    }
}
