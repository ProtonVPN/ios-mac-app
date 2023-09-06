//
//  CountryAnnotation.swift
//  ProtonVPN - Created on 01.07.19.
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

import CoreLocation
import UIKit
import LegacyCommon

class CountryAnnotation: AnnotationView {

    private let flagView: UIImageView
    private let flagOverlayView: UIView
    private let flagBoarderView: UIButton
    private let iconView: UIImageView
    private let countryLabel: UILabel
    private let flagContainerView: UIView
    
    var viewModel: AnnotationViewModel
    
    private var shown = false
    
    override var coordinate: CLLocationCoordinate2D {
        return viewModel.coordinate
    }

    override var connectedState: Bool {
        return viewModel.connectedUiState
    }
    
    var maxHeight: CGFloat {
        return viewModel.maxPinHeight + viewModel.labelHeight
    }
    
    var labelHeight: CGFloat {
        return viewModel.labelHeight
    }
    
    var width: CGFloat {
        return viewModel.labelWidth
    }
    
    override var available: Bool {
        return viewModel.available
    }
    
    override var selected: Bool {
        return viewModel.viewState == .selected
    }
    
    override var frame: CGRect {
        didSet {
            layer.anchorPoint = viewModel.anchorPoint
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    init(frame: CGRect, viewModel: AnnotationViewModel) {
        self.viewModel = viewModel
        self.flagView = UIImageView(image: viewModel.flag)
        self.flagBoarderView = UIButton(type: .custom)
        self.flagOverlayView = UIView()
        self.iconView = UIImageView(image: nil)
        self.countryLabel = UILabel(frame: CGRect.zero)
        self.flagContainerView = UIView()
        
        super.init(frame: frame)
        
        self.viewModel.buttonStateChanged = { [weak self] in
            self?.setNeedsDisplay() // redraw annotation on state change
        }
        
        flagView.clipsToBounds = true
        flagView.contentMode = .scaleAspectFill
        flagView.isUserInteractionEnabled = false // allow touch to fall through to button
        flagContainerView.clipsToBounds = true
        addSubview(flagContainerView)
        flagContainerView.addSubview(flagView)
        
        flagOverlayView.clipsToBounds = true
        flagOverlayView.isUserInteractionEnabled = false
        addSubview(flagOverlayView)
        
        flagBoarderView.addTarget(self, action: #selector(tapped), for: UIControl.Event.touchUpInside)
        addSubview(flagBoarderView)
        
        iconView.isUserInteractionEnabled = false // allow touch to fall through to button
        iconView.contentMode = .scaleAspectFill
        addSubview(iconView)
        
        countryLabel.clipsToBounds = true
        countryLabel.attributedText = viewModel.labelString
        countryLabel.isUserInteractionEnabled = false
        addSubview(countryLabel)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = viewModel.accessibilityLabel
        
        backgroundColor = .clear
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return flagBoarderView.point(inside: convert(point, to: flagBoarderView), with: event)
    }
    
    override func layerWillDraw(_ layer: CALayer) {
        super.layerWillDraw(layer)
        
        let outerCircleDiameter = viewModel.pinHeight - 6
        let innerCircleDiameter = outerCircleDiameter - 1.5 * viewModel.outlineWidth
        let outerCircleFrame = CGRect(x: 0.5 * (bounds.width - outerCircleDiameter), y: bounds.height - viewModel.labelHeight - viewModel.pinHeight, width: outerCircleDiameter, height: outerCircleDiameter)
        let innerCircleFrame = CGRect(x: 0.5 * (bounds.width - innerCircleDiameter), y: outerCircleFrame.minY + 0.75 * viewModel.outlineWidth, width: innerCircleDiameter, height: innerCircleDiameter)
        
        self.flagBoarderView.layer.borderColor = self.viewModel.outlineColor.cgColor
        
        self.iconView.image = self.viewModel.connectIcon
        self.iconView.tintColor = self.viewModel.connectIconTint
        
        let animationClosure = { [weak self] in
            guard let self = self else {
                return
            }
            
            self.flagContainerView.frame = innerCircleFrame
            self.flagContainerView.layer.cornerRadius = innerCircleDiameter * 0.5

            let flagViewNewHeight = self.flagContainerView.frame.height * 1.5
            self.flagView.frame = CGRect(x: 0, y: flagViewNewHeight / -6.0, width: self.flagContainerView.frame.width, height: flagViewNewHeight)
            
            self.flagOverlayView.frame = innerCircleFrame
            self.flagOverlayView.layer.cornerRadius = innerCircleDiameter * 0.5
            self.flagOverlayView.backgroundColor = self.viewModel.flagOverlayColor
            
            self.flagBoarderView.frame = outerCircleFrame
            self.flagBoarderView.layer.borderWidth = self.viewModel.outlineWidth
            self.flagBoarderView.layer.cornerRadius = outerCircleDiameter * 0.5
            self.flagBoarderView.backgroundColor = .clear
            
            self.iconView.frame = innerCircleFrame
            
            self.countryLabel.frame = CGRect(x: 0, y: self.bounds.height - self.viewModel.labelHeight, width: self.bounds.size.width, height: self.viewModel.labelHeight)
            self.countryLabel.layer.cornerRadius = self.viewModel.labelHeight * 0.5
            self.countryLabel.backgroundColor = self.viewModel.labelColor
            self.countryLabel.alpha = self.viewModel.hideLabel ? 0 : 1
        }
        
        if shown {
            UIView.animate(withDuration: 0.15, animations: animationClosure)
        } else {
            animationClosure()
            shown = true
        }
    }
    
    override func draw(_ rect: CGRect) {
        if viewModel.showAnchor {
            let pointPath = UIBezierPath()
            pointPath.move(to: CGPoint(x: rect.midX - 6, y: rect.maxY - viewModel.labelHeight - 8))
            pointPath.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - viewModel.labelHeight))
            pointPath.addLine(to: CGPoint(x: rect.midX + 6, y: rect.maxY - viewModel.labelHeight - 8))
            
            viewModel.outlineColor.setFill()

            pointPath.fill()
        }
    }
    
    @objc private func tapped() {
        viewModel.tapped()
    }
}
