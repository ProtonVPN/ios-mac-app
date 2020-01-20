//
//  CountryItemView.swift
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

class CountryItemView: NSView {
    
    @IBOutlet weak var cellSurfaceButton: CellSurfaceButton!
    @IBOutlet weak var countryFlagIcon: NSImageView!
    @IBOutlet weak var countryNameLabel: NSTextField!
    @IBOutlet weak var keywordIcon: FeatureIcon!
    @IBOutlet weak var connectButton: ConnectButton!
    @IBOutlet weak var expandCellButton: ExpandCellButton!
    @IBOutlet weak var rowSeparator: NSBox!
    
    private var viewModel: CountryItemViewModel!
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        
        // Executed on row addition
        if newSuperview != nil {
            trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
            setUpCallbacks()
        }
        // Executed on row removal
        else if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
    }
    
    override open func mouseEntered(with event: NSEvent) {
        isHovered = true
        hideConnectButton(false)
    }
    
    override open func mouseExited(with event: NSEvent) {
        isHovered = false
        hideConnectButton(!viewModel.isConnected)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    func updateView(withModel viewModel: CountryItemViewModel) {
        self.viewModel = viewModel
        
        setupCellSurfaceButton()
        setupCountryFlagIcon()
        
        countryNameLabel.attributedStringValue = viewModel.description
        
        setupKeywordIcon()
        setupConnectButton()
        setupExpandCellButton()
        
        setupBackground()
        rowSeparator.fillColor = NSColor.protonLightGrey()
        
        setUpCallbacks()
        
        setupAccessibility()
    }
    
    // MARK: - Private functions
    
    private func setUpCallbacks() {
        viewModel.cellStateChanged = { [unowned self] state in self.cellStateChanged(state) }
        viewModel.connectionChanged = { [unowned self] connected in self.connectionChanged(connected) }
    }
    
    private func setupKeywordIcon() {
        let feature = viewModel.feature
        if feature.rawValue <= 1 {
            keywordIcon.isHidden = true
            return
        }
        
        keywordIcon.image = viewModel.keywordImage
        keywordIcon.toolTip = viewModel.keywordTooltip
        
        keywordIcon.isHidden = false
    }
    
    private func setupCellSurfaceButton() {
        cellSurfaceButton.target = self
        cellSurfaceButton.action = #selector(changeCellStateButtonAction)
    }
    
    private func setupCountryFlagIcon() {
        countryFlagIcon.image = NSImage(named: NSImage.Name(viewModel.countryCode.lowercased() + "-plain"))
        countryFlagIcon.wantsLayer = true
        countryFlagIcon.layer?.cornerRadius = 2
    }
    
    private func setupConnectButton() {
        connectButton.isConnected = viewModel.isConnected
        hideConnectButton(!viewModel.isConnected)
        connectButton.target = self
        connectButton.action = #selector(connectButtonAction)
    }
    
    private func setupExpandCellButton() {
        expandCellButton.cellState = viewModel.state
        expandCellButton.target = self
        expandCellButton.action = #selector(changeCellStateButtonAction)
    }
    
    private func setupBackground() {
        countryNameLabel.backgroundColor = viewModel.backgroundColor
    }
    
    private func hideConnectButton(_ shouldHide: Bool) {
        connectButton.isHidden = shouldHide
        
        if viewModel.feature.rawValue <= 1 {
            keywordIcon.isHidden = true
        } else {
            keywordIcon.isHidden = !shouldHide
        }
    }
    
    @objc private func connectButtonAction() {
        viewModel.connectAction()
    }
    
    @objc private func changeCellStateButtonAction() {
        viewModel.changeCellState()
    }
    
    private func connectionChanged(_ isConnected: Bool) {
        connectButton.isConnected = isConnected
        hideConnectButton(isConnected ? false : !isHovered)
        setupBackground()
    }
    
    private func cellStateChanged(_ cellState: CellState) {
        expandCellButton.cellState = cellState
    }
    
    // MARK: - Accessibility
    
    private func setupAccessibility() {
        setAccessibilityLabel(String(format: "%@ %@", countryNameLabel?.attributedStringValue.string ?? "", viewModel.keywordTooltip ?? ""))
        connectButton.nameForAccessibility = viewModel.description.string
        connectButton.setAccessibilityElement(true)
        expandCellButton.setAccessibilityElement(true)
    }
    
    override func accessibilityChildren() -> [Any]? {
        return [connectButton]
    }
    
}
