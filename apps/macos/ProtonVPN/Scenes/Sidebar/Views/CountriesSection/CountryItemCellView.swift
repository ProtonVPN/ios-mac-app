//
//  CountryItemCellView.swift
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
import LegacyCommon
import Theme
import Ergonomics
import Strings
import ProtonCoreUIFoundations

final class CountryItemCellView: NSView {
    
    @IBOutlet private weak var flagIV: NSImageView!
    @IBOutlet private weak var secureIV: NSImageView!
    @IBOutlet private weak var countryLbl: NSTextField!
    @IBOutlet private weak var expandButton: ExpandCellButton!
    @IBOutlet private weak var connectButton: ConnectButton!
    @IBOutlet private weak var smartIV: NSImageView!
    @IBOutlet private weak var p2pIV: NSImageView!
    @IBOutlet private weak var torIV: NSImageView!
    @IBOutlet private weak var separatorView: NSView!
    @IBOutlet private weak var upgradeBtn: UpgradeButton!
    @IBOutlet private weak var maintenanceBtn: NSButton!
    
    private var viewModel: CountryItemViewModel!
    private var isHovered = false
    
    var disabled: Bool = false
        
    override func awakeFromNib() {
        super.awakeFromNib()
        
        expandButton.wantsLayer = true
        expandButton.layer?.cornerRadius = 16
        expandButton.layer?.borderWidth = 2
        expandButton.layer?.borderColor = .cgColor(.border, .weak)

        let imageMargin = 8
        maintenanceBtn.wantsLayer = true
        maintenanceBtn.layer?.cornerRadius = 16
        maintenanceBtn.image = AppTheme.Icon.wrench
            .colored(.weak)
            .resize(newWidth: Int(maintenanceBtn.bounds.width) - imageMargin,
                    newHeight: Int(maintenanceBtn.bounds.height) - imageMargin)
        maintenanceBtn.layer?.borderColor = .cgColor(.icon, .weak)
        maintenanceBtn.layer?.backgroundColor = .clear

        secureIV.toolTip = Localizable.secureCoreInfo
        secureIV.image = AppTheme.Icon.chevronsRight.colored([.interactive, .strong])
        torIV.toolTip = Localizable.torTitle
        torIV.image = AppTheme.Icon.brandTor.colored(.weak)
        p2pIV.toolTip = Localizable.p2pTitle
        p2pIV.image = AppTheme.Icon.arrowsSwitch.colored(.weak)
        smartIV.toolTip = Localizable.smartProtocolTitle
        smartIV.image = AppTheme.Icon.globe.colored(.weak)

        separatorView.wantsLayer = true
        DarkAppearance {
            separatorView.layer?.backgroundColor = .cgColor(.border, .weak)
        }
        let trackingFrame = NSRect(origin: frame.origin, size: CGSize(width: frame.size.width, height: frame.size.height - 4))
        let trackingArea = NSTrackingArea(rect: trackingFrame, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        expandButton.isEnabled = !disabled
        if disabled || viewModel.underMaintenance {
            mouseExited(with: event)
            return
        }
        connectButton.isHidden = isConnectButtonHidden(mouseHover: true)
        if !connectButton.isHidden {
            [torIV, p2pIV, smartIV].forEach {
                $0.isHidden = true
            }
        }
        addCursorRect(frame, cursor: .pointingHand)
    }
    
    override func mouseExited(with event: NSEvent) {
        expandButton.isEnabled = !disabled
        expandButton.isHovered = false
        upgradeBtn.isHovered = false
        connectButton.isHidden = isConnectButtonHidden(mouseHover: false)
        configureFeatures()
        removeCursorRect(frame, cursor: .pointingHand)
    }

    func updateView(withModel viewModel: CountryItemViewModel) {
        self.viewModel = viewModel
        
        [torIV, p2pIV, smartIV, secureIV, expandButton, flagIV, countryLbl, maintenanceBtn].forEach {
            $0?.alphaValue = viewModel.alphaForMainElements
        }
    
        separatorView.isHidden = !viewModel.displaySeparator
        secureIV.isHidden = !viewModel.secureCoreEnabled
        
        expandButton.image = viewModel.isOpened ? AppTheme.Icon.chevronUp : AppTheme.Icon.chevronDown
        countryLbl.stringValue = viewModel.countryName
        if !viewModel.countryCode.isEmpty {
            flagIV.image = AppTheme.Icon.flag(countryCode: viewModel.countryCode)
        } else {
            flagIV.image = IconProvider.servers
        }
        connectButton.isConnected = viewModel.isConnected
        connectButton.isHidden = isConnectButtonHidden(mouseHover: false)
        upgradeBtn.isHidden = !viewModel.isTierTooLow || viewModel.underMaintenance
        expandButton.isHidden = viewModel.isTierTooLow || viewModel.underMaintenance
        maintenanceBtn.isHidden = !viewModel.underMaintenance
        connectButton.isHovered = false
        expandButton.isHovered = false
        configureFeatures()
        setupAccessibilityCustomActions()
    }

    private func isConnectButtonHidden(mouseHover: Bool) -> Bool {
        // Hide if hidden or tier too low to connect
        guard viewModel.showCountryConnectButton && !viewModel.isTierTooLow else { return true }
        // Show on mouse hover
        guard !mouseHover else { return false }
        // Show if connected to this country
        return !viewModel.isConnected
    }

    // MARK: - Actions
    
    @IBAction private func didTapExpandBtn(_ sender: Any) {
        if viewModel.isServerUnderMaintenance || viewModel.isTierTooLow { return }
        viewModel.changeCellState()
        expandButton.image = viewModel.isOpened ? AppTheme.Icon.chevronUp : AppTheme.Icon.chevronDown
        setupAccessibilityCustomActions()
    }
    
    @IBAction private func didTapUpgradeBtn(_ sender: Any) {
        viewModel.upgradeAction()
    }
    
    @IBAction func didTapConnectBtn(_ sender: Any) {
        viewModel.connectAction()
    }
    
    // MARK: - Private
    
    private func configureFeatures() {
        if viewModel.showFeatureIcons {
            torIV.isHidden = !viewModel.isTorAvailable || viewModel.isConnected
            p2pIV.isHidden = !viewModel.isP2PAvailable || viewModel.isConnected
            smartIV.isHidden = !viewModel.isSmartAvailable || viewModel.isConnected
        } else {
            [torIV, p2pIV, smartIV].forEach {
                $0.isHidden = true
            }
        }
    }
    
    // MARK: - Accessibility

    override func accessibilityLabel() -> String? {
        viewModel.accessibilityLabel
    }

    private func setupAccessibilityCustomActions() {
        connectButton.nameForAccessibility = viewModel.countryName
        var actions = [NSAccessibilityCustomAction]()

        if !expandButton.isHidden {
            let name = viewModel.isOpened ? Localizable.collapseListOfServers : Localizable.expandListOfServers
            actions.append(NSAccessibilityCustomAction(name: name, target: self, selector: #selector(didTapExpandBtn(_:))))
        }
        if upgradeBtn.isHidden {
            let name = connectButton.isConnected ? Localizable.disconnect : Localizable.connect
            actions.append(NSAccessibilityCustomAction(name: name, target: self, selector: #selector(didTapConnectBtn(_:))))
        } else {
            actions.append(NSAccessibilityCustomAction(name: Localizable.upgrade, target: self, selector: #selector(didTapUpgradeBtn(_:))))
        }

        setAccessibilityCustomActions(actions)
    }

    override func accessibilityChildren() -> [Any]? {
        return []
    }
}
