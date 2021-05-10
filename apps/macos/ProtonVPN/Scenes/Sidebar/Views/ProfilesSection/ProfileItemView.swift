//
//  ProfileItemView.swift
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
import vpncore

class ProfileItemView: NSView {

    @IBOutlet weak var profileImage: NSImageView!
    @IBOutlet weak var profileCircle: ProfileCircle!
    @IBOutlet weak var profileName: NSTextField!
    @IBOutlet weak var secondaryDescription: PVPNTextField!
    @IBOutlet weak var nameToDescriptionConstraint: NSLayoutConstraint!
    @IBOutlet weak var connectButton: ConnectButton!
    @IBOutlet weak var rowSeparator: NSBox!

    private var viewModel: ProfileItemViewModel!
    private var trackingArea: NSTrackingArea?
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        
        if newSuperview != nil {
            trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        } else if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
    }
    
    override open func mouseEntered(with event: NSEvent) {
        connectButton.isHidden = !viewModel.enabled
    }
    
    override open func mouseExited(with event: NSEvent) {
        connectButton.isHidden = true
    }
    
    func updateView(withModel viewModel: ProfileItemViewModel) {
        self.viewModel = viewModel
        
        setupImage()
        setupProfileName()
        setupSecondaryDescription()
        setupConnectButton()
        setupAccessibility()
        setupAvailability()
        
        rowSeparator.fillColor = .protonLightGrey()
    }
    
    // MARK: - Private functions
    private func setupImage() {
        switch viewModel.icon {
        case .image(let image):
            profileImage.image = NSImage(named: NSImage.Name(image))
            profileImage.isHidden = false
            profileCircle.isHidden = true
        case .circle(let color):
            profileCircle.profileColor = NSColor(rgbHex: color)
            profileImage.isHidden = true
            profileCircle.isHidden = false
        }
    }
    
    private func setupProfileName() {
        profileName.attributedStringValue = viewModel.name
        profileName.usesSingleLineMode = true
    }
    
    private func setupSecondaryDescription() {
        secondaryDescription.isHidden = viewModel.hideDescription
        nameToDescriptionConstraint.constant = viewModel.hideDescription ? 0 : 15
        secondaryDescription.attributedStringValue = viewModel.secondaryDescription
    }
    
    private func setupConnectButton() {
        connectButton.isHidden = true
        connectButton.target = self
        connectButton.action = #selector(connectButtonAction)
    }
    
    @objc private func connectButtonAction() {
        viewModel.connectAction()
    }
    
    private func setupAccessibility() {
        setAccessibilityLabel(viewModel?.name.string)
    }
    
    private func setupAvailability() {
        [profileImage, profileCircle, profileName, secondaryDescription].forEach { view in
            view?.alphaValue = viewModel.alphaOfMainElements
        }
        connectButton.upgradeRequired = viewModel.isUsersTierTooLow
    }
    
    // MARK: - Accessibility
    
    override func accessibilityChildren() -> [Any]? {
        return [connectButton]
    }
    
}
