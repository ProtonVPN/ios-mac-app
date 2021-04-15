//
//  ConnectingViewController.swift
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

class ConnectingViewController: NSViewController, OverlayViewModelDelegate {

    @IBOutlet private weak var graphicContainer: NSView!
    @IBOutlet private weak var phaseLabel: NSTextField!
    @IBOutlet private weak var connectionLabel: NSTextField!
    @IBOutlet private var firstButton: ConnectingOverlayButton! // Cancel
    @IBOutlet private var secondButton: ConnectingOverlayButton! // Retry
    @IBOutlet private var thirdButton: ConnectingOverlayButton! // Switch to openVPN
    
    @IBOutlet private weak var mainStackView: NSStackView!
    @IBOutlet private weak var buttonsStackView: NSStackView!
    private var temporaryButtonConstraints = [NSLayoutConstraint]()
    
    private let viewModel: ConnectingOverlayViewModel
    
    private var completionHandler: (() -> Void)?
    
    // MARK: - Public functions
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: ConnectingOverlayViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ConnectingOverlay"), bundle: nil)
        
        self.viewModel.delegate = self
        
        self.view.setAccessibilityModal(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        update()
    }
    
    func fade(over time: TimeInterval, completion: @escaping () -> Void) {
        completionHandler = completion
        
        let layerAnimation = CABasicAnimation(keyPath: "opacity")
        layerAnimation.fromValue = 1.0
        layerAnimation.toValue = 0.0
        layerAnimation.duration = time
        firstButton.layer?.add(layerAnimation, forKey: "fadeAnimation")
        firstButton.layer?.opacity = 0.0
        
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = time
            view.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let `self` = self else { return }
            self.stopAnimatingFade()
        })
    }
    
    func stopAnimatingFade() {
        guard let completionHandler = completionHandler else { return }
        
        completionHandler()
        self.completionHandler = nil
    }
    
    // MARK: - Private functions
    
    private func update() {
        let graphic = viewModel.graphic(with: graphicContainer.bounds)
        if !graphicContainer.subviews.contains(graphic) {
            graphicContainer.subviews.forEach {
                $0.removeFromSuperview()
            }
            graphicContainer.addSubview(graphic)
        }
        phaseLabel.isHidden = viewModel.hidePhase
        phaseLabel.attributedStringValue = viewModel.firstString
        
        connectionLabel.attributedStringValue = viewModel.secondString
        connectionLabel.allowsEditingTextAttributes = true
        connectionLabel.isSelectable = true
        
        updateButtons()
    }
    
    private func updateButtons() {
        firstButton.title = viewModel.firstButtonTitle
        firstButton.style = viewModel.firstButtonStyle
    
        secondButton.isHidden = viewModel.hideSecondButton
        secondButton.title = viewModel.secondButtonTitle
        secondButton.style = viewModel.secondButtonStyle
        
        thirdButton.isHidden = viewModel.hideThirdButton
        thirdButton.title = viewModel.thirdButtonTitle
        thirdButton.style = viewModel.thirdButtonStyle
                
        NSLayoutConstraint.deactivate(temporaryButtonConstraints)
        temporaryButtonConstraints.removeAll()
        
        if !viewModel.hideThirdButton && !viewModel.hideSecondButton {
            buttonsStackView.orientation = .vertical
            buttonsStackView.alignment = .centerX
            buttonsStackView.clear()
            buttonsStackView.addArrangedSubview(thirdButton)
            buttonsStackView.addArrangedSubview(secondButton)
            buttonsStackView.addArrangedSubview(firstButton)
            temporaryButtonConstraints.append(contentsOf: buttonsStackView.childrenFillWidth())
                        
        } else if !viewModel.hideSecondButton && secondButton.title.count > 10 { // "Try againg".count == 9
            buttonsStackView.orientation = .vertical
            buttonsStackView.alignment = .centerX
            buttonsStackView.clear()
            buttonsStackView.addArrangedSubview(secondButton)
            buttonsStackView.addArrangedSubview(firstButton)
            temporaryButtonConstraints.append(contentsOf: buttonsStackView.childrenFillWidth())
            
        } else {
            buttonsStackView.orientation = .horizontal
            buttonsStackView.alignment = .top
            buttonsStackView.clear()
            buttonsStackView.addArrangedSubview(firstButton)
            buttonsStackView.addArrangedSubview(secondButton)
        }
    }
    
    // MARK: - Actions
    
    @IBAction private func cancelConnecting(_ sender: Any) {
        viewModel.cancelConnecting()
    }
    
    @IBAction private func retryConneting(_ sender: Any) {
        viewModel.retryConnection()
    }
    
    @IBAction private func switchToOpenVPN(_ sender: Any) {
        viewModel.reconnectWithOvpn()
    }
    
    // MARK: - OverlayViewModelDelegate
    
    func stateChanged() {
        update()
    }
    
}
