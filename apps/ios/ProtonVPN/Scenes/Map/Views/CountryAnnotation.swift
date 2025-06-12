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
        viewModel.coordinate
    }

    override var connectedState: Bool {
        viewModel.connectedUiState
    }
    
    var maxHeight: CGFloat {
        viewModel.maxPinHeight + viewModel.labelHeight
    }
    
    var labelHeight: CGFloat {
        viewModel.labelHeight
    }
    
    var width: CGFloat {
        viewModel.labelWidth
    }
    
    override var available: Bool {
        viewModel.available
    }
    
    override var selected: Bool {
        viewModel.viewState == .selected
    }
    
    override var frame: CGRect {
        didSet {
            layer.anchorPoint = viewModel.anchorPoint
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    init(frame: CGRect, viewModel: AnnotationViewModel) {
        self.viewModel = viewModel
        flagView = UIImageView(image: viewModel.flag)
        flagBoarderView = UIButton(type: .custom)
        flagOverlayView = UIView()
        iconView = UIImageView(image: nil)
        countryLabel = UILabel(frame: CGRect.zero)
        flagContainerView = UIView()
        
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
        flagBoarderView.point(inside: convert(point, to: flagBoarderView), with: event)
    }
    
    override func layerWillDraw(_ layer: CALayer) {
        super.layerWillDraw(layer)
        
        let outerCircleDiameter = viewModel.pinHeight - 6
        let innerCircleDiameter = outerCircleDiameter - 1.5 * viewModel.outlineWidth
        let outerCircleFrame = CGRect(x: 0.5 * (bounds.width - outerCircleDiameter), y: bounds.height - viewModel.labelHeight - viewModel.pinHeight, width: outerCircleDiameter, height: outerCircleDiameter)
        let innerCircleFrame = CGRect(x: 0.5 * (bounds.width - innerCircleDiameter), y: outerCircleFrame.minY + 0.75 * viewModel.outlineWidth, width: innerCircleDiameter, height: innerCircleDiameter)
        
        flagBoarderView.layer.borderColor = viewModel.outlineColor.cgColor
        
        iconView.image = viewModel.connectIcon
        iconView.tintColor = viewModel.connectIconTint
        
        let animationClosure = { [weak self] in
            guard let self else {
                return
            }
            
            flagContainerView.frame = innerCircleFrame
            flagContainerView.layer.cornerRadius = innerCircleDiameter * 0.5

            let flagViewNewHeight = flagContainerView.frame.height * 1.5
            flagView.frame = CGRect(x: 0, y: flagViewNewHeight / -6.0, width: flagContainerView.frame.width, height: flagViewNewHeight)
            
            flagOverlayView.frame = innerCircleFrame
            flagOverlayView.layer.cornerRadius = innerCircleDiameter * 0.5
            flagOverlayView.backgroundColor = viewModel.flagOverlayColor
            
            flagBoarderView.frame = outerCircleFrame
            flagBoarderView.layer.borderWidth = viewModel.outlineWidth
            flagBoarderView.layer.cornerRadius = outerCircleDiameter * 0.5
            flagBoarderView.backgroundColor = .clear
            
            iconView.frame = innerCircleFrame
            
            countryLabel.frame = CGRect(x: 0, y: bounds.height - viewModel.labelHeight, width: bounds.size.width, height: viewModel.labelHeight)
            countryLabel.layer.cornerRadius = viewModel.labelHeight * 0.5
            countryLabel.backgroundColor = viewModel.labelColor
            countryLabel.alpha = viewModel.hideLabel ? 0 : 1
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
