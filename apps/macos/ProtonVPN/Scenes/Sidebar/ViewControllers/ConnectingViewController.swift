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

    @IBOutlet weak var graphicContainer: NSView!
    @IBOutlet weak var phaseLabel: NSTextField!
    @IBOutlet weak var connectionLabel: NSTextField!
    @IBOutlet weak var cancelButton: ConnectingOverlayButton!
    @IBOutlet weak var retryButton: ConnectingOverlayButton!
    
    let viewModel: ConnectingOverlayViewModel
    
    var completionHandler: (() -> Void)?
    
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
        cancelButton.layer?.add(layerAnimation, forKey: "fadeAnimation")
        cancelButton.layer?.opacity = 0.0
        
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
        phaseLabel.attributedStringValue = viewModel.phaseString
        connectionLabel.attributedStringValue = viewModel.connectingString
        cancelButton.title = viewModel.cancelButtonTitle
        cancelButton.color = viewModel.cancelButtonColor
        retryButton.isHidden = viewModel.hideRetryButton
        retryButton.title = viewModel.retryButtonTitle
    }
    
    @IBAction private func cancelConnecting(_ sender: Any) {
        viewModel.cancelConnecting()
    }
    
    @IBAction private func retryConneting(_ sender: Any) {
        viewModel.retryConnection()
    }
    
    // MARK: - OverlayViewModelDelegate
    func stateChanged() {
        update()
    }
}
