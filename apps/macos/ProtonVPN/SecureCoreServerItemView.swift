//
//  SecureCoreServerItemView.swift
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

class SecureCoreServerItemView: NSView {
    
    @IBOutlet weak var loadIcon: ColoredLoadButton!
    @IBOutlet weak var countryFlagIcon: NSImageView!
    @IBOutlet weak var countryNameLabel: PVPNTextField!
    @IBOutlet weak var secondaryDescription: PVPNTextField!
    @IBOutlet weak var connectButton: ConnectButton!
    
    private var viewModel: SecureCoreServerItemViewModel!
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    
    var showServerInfo: (() -> Void)?
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        
        // Executed on row addition
        if newSuperview != nil {
            trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
        // Executed on row removal
        else if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if viewModel.isParentExpanded() {
            isHovered = true
            hideConnectButton(!viewModel.enabled)
            addCursorRect(bounds, cursor: .arrow)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        hideConnectButton(!viewModel.isConnected)
        removeCursorRect(bounds, cursor: .arrow)
    }
    
    func updateView(withModel viewModel: SecureCoreServerItemViewModel) {
        self.viewModel = viewModel
        
        setupCountryFlagIcon()
        
        countryNameLabel.attributedStringValue = viewModel.description
        secondaryDescription.attributedStringValue = viewModel.secondaryDescription
        
        loadIcon.load = viewModel.load
        setupInfoButton()
        setupConnectButton()
        
        setupBackground()
        
        viewModel.connectionChanged = { [unowned self] connected in self.connectionChanged(connected) }
        self.setAccessibilityLabel(viewModel.fullDescription)
        
    }
    
    // MARK: - Private functions
    
    private func setupInfoButton() {
        loadIcon.target = self
        loadIcon.action = #selector(showInfo)
    }
    
    private func setupBackground() {
        countryNameLabel.backgroundColor = viewModel.backgroundColor
        secondaryDescription.backgroundColor = viewModel.backgroundColor
    }
    
    private func setupCountryFlagIcon() {
        countryFlagIcon.image = NSImage(named: NSImage.Name(viewModel.countryCode.lowercased() + "-plain"))
        countryFlagIcon.wantsLayer = true
        countryFlagIcon.layer?.cornerRadius = 2
    }
    
    private func setupConnectButton() {
        connectButton.isConnected = viewModel.isConnected
        connectButton.upgradeRequired = viewModel.requiresUpgrade
        hideConnectButton(!viewModel.isConnected)
        connectButton.target = self
        connectButton.action = #selector(connectButtonAction)
        connectButton.nameForAccessibility = viewModel.description.string
    }
    
    private func hideConnectButton(_ hide: Bool) {
        connectButton.isHidden = hide
        secondaryDescription.isHidden = !hide
    }
    
    @objc private func connectButtonAction() {
        viewModel.connectAction()
    }
    
    private func connectionChanged(_ isConnected: Bool) {
        setupBackground()
        connectButton.isConnected = isConnected
        hideConnectButton(isConnected ? false : !isHovered)
    }
    
    @objc private func showInfo() {
        if let showServerInfo = showServerInfo {
            showServerInfo()
        }
    }

    // MARK: - Accessibility
    
    override func accessibilityChildren() -> [Any]? {
        return [connectButton]
    }
    
}
