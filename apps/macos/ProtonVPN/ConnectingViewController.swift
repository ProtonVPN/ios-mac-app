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
    @IBOutlet private var cancelButton: ConnectingOverlayButton!
    @IBOutlet private var retryButton: ConnectingOverlayButton!
    
    @IBOutlet private weak var mainStackView: NSStackView!
    @IBOutlet private weak var buttonsStackView: NSStackView!
    
    @IBOutlet private weak var connectionLabelContainer: NSView!
    private let textView = NSTextView()
    
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
        phaseLabel.attributedStringValue = viewModel.firstString
        
        setupTextView()
        textView.textStorage?.setAttributedString(viewModel.secondString)
        
        connectionLabel.attributedStringValue = viewModel.secondString
        connectionLabel.allowsEditingTextAttributes = true
        connectionLabel.isSelectable = true
        
        cancelButton.title = viewModel.cancelButtonTitle
        cancelButton.style = viewModel.cancelButtonStyle
        
        retryButton.isHidden = viewModel.hideRetryButton
        retryButton.title = viewModel.retryButtonTitle
        retryButton.style = viewModel.retryButtonStyle
        
        if retryButton.title.count > 10 { // "Try againg".count == 9
            buttonsStackView.orientation = .vertical
            buttonsStackView.alignment = .centerX
            buttonsStackView.arrangedSubviews.forEach {
                buttonsStackView.removeArrangedSubview( $0 )
            }
            buttonsStackView.addArrangedSubview(retryButton)
            buttonsStackView.addArrangedSubview(cancelButton)
        } else {
            buttonsStackView.orientation = .horizontal
            buttonsStackView.arrangedSubviews.forEach {
                buttonsStackView.removeArrangedSubview( $0 )
            }
            buttonsStackView.addArrangedSubview(cancelButton)
            buttonsStackView.addArrangedSubview(retryButton)
        }
        
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
    
    private func setupTextView() {
        guard !textView.isDescendant(of: connectionLabelContainer) else {
            return
        }
        
        textView.linkTextAttributes = [
            NSAttributedString.Key.foregroundColor: NSColor.protonGreen(),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        textView.isEditable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        
        connectionLabelContainer.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: connectionLabel.topAnchor, constant: 0),
            textView.bottomAnchor.constraint(equalTo: connectionLabel.bottomAnchor, constant: 0),
            textView.leadingAnchor.constraint(equalTo: connectionLabel.leadingAnchor, constant: -4), // This is magic padding that puts NSTextView's text at the same place as in connectionLabel.
            textView.trailingAnchor.constraint(equalTo: connectionLabel.trailingAnchor, constant: 4), // See above ^.
        ])
        
        connectionLabel.alphaValue = 0.0
    }
    
}

extension ConnectingViewController: NSTextViewDelegate {
    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else {
            return false
        }
        viewModel.open(link: url)
        return true
    }
    
}
