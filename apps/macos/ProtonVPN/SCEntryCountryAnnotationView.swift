//
//  SCEntryCountryAnnotationView.swift
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

class SCEntryCountryAnnotationView: MKAnnotationView {
    
    private let buttonHeight: CGFloat = 30
    private let buttonWidth: CGFloat
    private let buttonFrame: CGRect
    
    private let triangleWidth: CGFloat = 17
    private let triangleHeight: CGFloat = 14
    
    private let circleDiameter: CGFloat = 14

    private var triangleFrame: CGRect = CGRect()
    
    let viewModel: SCEntryCountryAnnotationViewModel
    
    private var containerView: NSView?
    
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
    
    init(viewModel: SCEntryCountryAnnotationViewModel, reuseIdentifier: String?) {
        self.viewModel = viewModel
        buttonWidth = viewModel.buttonWidth
        
        buttonFrame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        
        super.init(annotation: nil, reuseIdentifier: reuseIdentifier)
        
        viewModel.viewStateChange = { [weak self] in
            guard let `self` = self else { return }
            self.setupAnnotationView()
            self.needsDisplay = true
        }
        
        setupAnnotationView()
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin - NSPoint(x: buttonWidth / 2, y: circleDiameter / 2))
    }
    
    // swiftlint:disable operator_usage_whitespace
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if viewModel.state == .hovered {
            context.setStrokeColor(stateColor(for: NSColor.protonGreen()))
            context.setFillColor(stateColor(for: viewModel.isConnected ? NSColor.protonGreen() : NSColor.protonGreyShade()))
            
            let lineWidth: CGFloat = 1.0
            
            // triangle
            let itf/*innerTriangleFrame*/ = CGRect(x: triangleFrame.origin.x + lineWidth/2, y: triangleFrame.origin.y + lineWidth/2, width: triangleFrame.width - lineWidth, height: triangleFrame.height - lineWidth)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: itf.origin.x, y: itf.origin.y))
            context.addLine(to: CGPoint(x: itf.origin.x + itf.width / 2, y: itf.origin.y + itf.height))
            context.addLine(to: CGPoint(x: itf.origin.x + itf.width, y: itf.origin.y))
        
            // button
            let ibf/*innerButtonFrame*/ = CGRect(x: lineWidth/2, y: lineWidth/2, width: buttonWidth - lineWidth, height: buttonHeight)
            context.addLine(to: CGPoint(x: ibf.maxX - ibf.height/2, y: ibf.maxY))
            context.addArc(center: CGPoint(x: ibf.maxX - ibf.height/2, y: ibf.maxY - ibf.height/2), radius: ibf.height/2, startAngle: .pi/2, endAngle: .pi*3/2, clockwise: true)
            context.addLine(to: CGPoint(x: ibf.minX + ibf.height/2, y: ibf.minY))
            context.addArc(center: CGPoint(x: ibf.minX + ibf.height/2, y: ibf.maxY - ibf.height/2), radius: ibf.height/2, startAngle: .pi*3/2, endAngle: .pi/2, clockwise: true)
        
            // close shape (either top of triangle or last section of button)
            context.closePath()
            context.drawPath(using: .fillStroke)
        
            let attributedTitle = viewModel.attributedCountry
            let textHeight = attributedTitle.size().height
            attributedTitle.draw(in: CGRect(x: 0, y: (buttonHeight - textHeight) / 2, width: buttonWidth, height: textHeight))
        }
    }
    // swiftlint:enable operator_usage_whitespace
    
    // MARK: - Private functions
    private func stateColor(for color: NSColor) -> CGColor {
        return color.cgColor
    }
    
    private func setupAnnotationView() {
        setSelection()
        setupFrame()
        recycleContainerView()
        setupContainerComponents()
    }
    
    private func setSelection() {
        if viewModel.state == .idle {
            setSelected(false, animated: false)
        } else {
            setSelected(true, animated: true)
        }
    }
    
    private func setupFrame() {
        let height: CGFloat
        switch viewModel.state {
        case .idle:
            height = circleDiameter
            tag = -1 // default view tag
        case .hovered:
            height = circleDiameter + triangleHeight + buttonHeight
            
            // brings this view to the forefront of the superview's subviews except for any open exit views
            if let parentView = superview {
                tag = 50 // less than hovered exit countries
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
        let triangleOrigin = NSPoint(x: (buttonWidth - triangleWidth) / CGFloat(2), y: bounds.height - triangleHeight - circleDiameter)
        let triangleSize = NSSize(width: triangleWidth, height: triangleHeight)
        triangleFrame = CGRect(origin: triangleOrigin, size: triangleSize)
    }
    
    private func recycleContainerView() {
        if let containerView = containerView {
            containerView.removeFromSuperview()
        }
        
        containerView = NSView(frame: NSRect(origin: NSPoint(x: 0, y: 0), size: frame.size))
        addSubview(containerView!)
    }
    
    private func setupContainerComponents() {
        positionCircleButton()
    }
    
    private func positionCircleButton() {
        guard let containerView = containerView else {
            return
        }
        
        let origin = NSPoint(x: (frame.size.width - circleDiameter) / CGFloat(2), y: 0)
        let size = NSSize(width: circleDiameter, height: circleDiameter)
        
        let circleState: SCCoreCircleButton.ButtonState
        if viewModel.isConnected || viewModel.state == .hovered {
            circleState = .active
        } else {
            circleState = .idle
        }
        
        let circleButton = SCCoreCircleButton(frame: NSRect(origin: origin, size: size),
                                              state: circleState)
        circleButton.target = self
        circleButton.action = #selector(circleButtonAction)
        
        containerView.addSubview(circleButton)
    }
    
    @objc private func circleButtonAction() {
        viewModel.toggleState()
    }
}
