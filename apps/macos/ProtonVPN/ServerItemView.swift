//
//  ServerItemView.swift
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

class ServerItemView: NSView {
    
    @IBOutlet weak var maintenanceIcon: WrenchIcon!
    @IBOutlet weak var loadIcon: ColoredLoadButton!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var secondaryDescription: NSTextField!
    @IBOutlet weak var keywordStackView: NSStackView!
    @IBOutlet weak var connectButton: ConnectButton!
    
    private var viewModel: ServerItemViewModel!
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    var showServerInfo: (() -> Void)?
    
    public var disabled: Bool = false
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        // Executed on row addition
        if newSuperview != nil && !disabled {
            trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
        // Executed on row removal
        else if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if disabled { return }
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
    
    func updateView(withModel viewModel: ServerItemViewModel) {
        self.viewModel = viewModel
        loadIcon.load = viewModel.load
        descriptionLabel.attributedStringValue = viewModel.description
        secondaryDescription.attributedStringValue = viewModel.secondaryDescription
        
        setupInfoView()
        setupKeywordIcon()
        setupConnectButton()
        setupBackground()
        viewWillMove(toSuperview: superview)
        viewModel.connectionChanged = { [unowned self] connected in self.connectionChanged(connected) }
    }
    
    // MARK: - Private functions

    private func setupInfoView() {
        let isUnderMaintenance = viewModel.underMaintenance
        loadIcon.isHidden = isUnderMaintenance
        maintenanceIcon.isHidden = !isUnderMaintenance
        if !isUnderMaintenance {
            loadIcon.target = self
            loadIcon.action = #selector(showInfo)
        }
    }
    
    private func setupBackground() {
        descriptionLabel.backgroundColor = viewModel.backgroundColor
        secondaryDescription.backgroundColor = viewModel.backgroundColor
    }
    
    private func setupKeywordIcon() {
        let icons = viewModel.keywordIcons
        
        var iconViews = [FeatureIcon]()
        icons.forEach { (image, toolTip) in
            let keywordIcon = FeatureIcon()
            let iconWidth = NSLayoutConstraint(item: keywordIcon,
                                               attribute: .width,
                                               relatedBy: .equal,
                                               toItem: nil,
                                               attribute: .notAnAttribute,
                                               multiplier: 1,
                                               constant: 20)
            let iconHeight = NSLayoutConstraint(item: keywordIcon,
                                               attribute: .height,
                                               relatedBy: .equal,
                                               toItem: nil,
                                               attribute: .notAnAttribute,
                                               multiplier: 1,
                                               constant: 20)
            keywordIcon.addConstraints([iconWidth, iconHeight])
            
            keywordIcon.image = image
            keywordIcon.toolTip = toolTip
            
            iconViews.append(keywordIcon)
        }
        
        keywordStackView.setViews(iconViews, in: .center)
    }
    
    private func setupConnectButton() {
        connectButton.isConnected = viewModel.isConnected
        connectButton.upgradeRequired = viewModel.requiresUpgrade
        connectButton.isEnabled = !disabled
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
