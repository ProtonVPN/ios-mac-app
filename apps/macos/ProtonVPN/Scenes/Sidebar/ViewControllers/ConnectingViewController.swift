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
    
    @IBOutlet private weak var mainStackView: NSStackView!
    @IBOutlet private weak var buttonsStackView: NSStackView!
        
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
        buttonsStackView.layer?.add(layerAnimation, forKey: "fadeAnimation")
        buttonsStackView.layer?.opacity = 0.0
        
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = time
            view.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else {
                return
            }

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
        var buttons = viewModel.buttons
        
        clickHandlers.removeAll()
        buttonsStackView.clear()
        buttonsStackView.alignment = .centerX
        buttonsStackView.orientation = buttons.count > 2 || buttons.count > 1 && buttons[1].0.count > 9 // "Try againg".count == 9
            ? .vertical
            : .horizontal
        
        // Put cancel button on the left
        if buttonsStackView.orientation == .horizontal && buttons.count == 2 {
            buttons.reverse()
        }
        
        for (index, buttonInfo) in buttons.enumerated() {
            add(button: buttonInfo, atIndex: index)
        }
        
    }
    
    private func add(button buttonInfo: ConnectingOverlayViewModel.ButtonInfo, atIndex index: Int) {
        let button = ConnectingOverlayButton(title: buttonInfo.0, target: self, action: #selector(buttonClicked))
        button.awakeFromNib()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.horizontalPadding = 15
        buttonsStackView.addArrangedSubview(button)
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        if buttonsStackView.orientation == .vertical {
            button.widthAnchor.constraint(equalTo: buttonsStackView.widthAnchor, multiplier: 1).isActive = true
        } else {
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        }
        
        button.title = buttonInfo.0
        button.style = buttonInfo.1
        clickHandlers.append(buttonInfo.2)
        button.tag = index
        button.target = self
        button.action = #selector(buttonClicked)
    }
    
    // MARK: - Actions
        
    private var clickHandlers = [() -> Void]()
    
    @IBAction private func buttonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < clickHandlers.count else {
            return
        }
        clickHandlers[index]()
    }
    
    // MARK: - OverlayViewModelDelegate
    
    func stateChanged() {
        update()
    }
    
}
