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
import Theme

class SCEntryCountryAnnotationView: MapAnnotationView {
    private static let circleDiameter: CGFloat = 14

    let viewModel: SCEntryCountryAnnotationViewModel

    var hovered: Bool {
        viewModel.state == .hovered
    }

    override var triangleFrame: CGRect {
        let origin = CGPoint(x: (buttonFrame.size.width - Self.triangleSize.width) / CGFloat(2),
                             y: bounds.height - Self.triangleSize.height - Self.circleDiameter)
        return CGRect(origin: origin, size: Self.triangleSize)
    }
    
    private var containerView: NSView?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer \(#function)")
    }

    required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        fatalError("Unsupported initializer \(#function)")
    }
    
    init(viewModel: SCEntryCountryAnnotationViewModel, reuseIdentifier: String?) {
        self.viewModel = viewModel

        super.init(buttonSize: CGSize(width: viewModel.buttonWidth,
                                      height: MapAnnotationView.textLineHeight),
                   hoveredTag: .middle,
                   styleDelegate: viewModel,
                   reuseIdentifier: reuseIdentifier)

        viewModel.viewStateChange = { [weak self] in
            guard let self = self else {
                return
            }

            self.setupAnnotationView()
            self.needsDisplay = true
        }
        
        setupAnnotationView()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin - NSPoint(x: 0, y: Self.circleDiameter / 2))
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        guard hovered else { return }

        drawAnnotation(context: context, text: [viewModel.attributedCountry])
    }

    // MARK: - Private functions
    
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
        let hovered: Bool
        switch viewModel.state {
        case .idle:
            height = Self.circleDiameter
            hovered = false
        case .hovered:
            height = Self.circleDiameter + Self.triangleSize.height + buttonFrame.size.height
            hovered = true
        }

        orderInForeground(hovered: hovered)
        setFrameSize(NSSize(width: buttonFrame.size.width, height: height))
        centerOffset = NSPoint(x: 0, y: -frame.size.height / 2)
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
        
        let origin = NSPoint(x: (frame.size.width - Self.circleDiameter) / CGFloat(2), y: 0)
        let size = NSSize(width: Self.circleDiameter, height: Self.circleDiameter)
        
        let circleState: SCCoreCircleButton.ButtonState
        if viewModel.isConnected || hovered {
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
