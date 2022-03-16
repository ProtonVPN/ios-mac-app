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
import vpncore
import ProtonCore_UIFoundations

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
    @IBOutlet private weak var upgradeBtn: NSButton!
    @IBOutlet private weak var maintenanceBtn: NSButton!
    
    private var viewModel: CountryItemViewModel!
    private var isHovered = false
    
    var disabled: Bool = false
        
    override func awakeFromNib() {
        super.awakeFromNib()
        upgradeBtn.stringValue = LocalizedString.upgrade
        
        expandButton.wantsLayer = true
        expandButton.layer?.cornerRadius = 16
        expandButton.layer?.borderWidth = 2
        expandButton.layer?.borderColor = NSColor.protonExandableButton().cgColor
        
        maintenanceBtn.wantsLayer = true
        maintenanceBtn.layer?.cornerRadius = 16
        maintenanceBtn.layer?.backgroundColor = NSColor.protonServerRow().cgColor
        
        torIV.toolTip = LocalizedString.torTitle
        p2pIV.toolTip = LocalizedString.p2pTitle
        smartIV.toolTip = LocalizedString.smartProtocolTitle

        torIV.image = IconProvider.brandTor
        p2pIV.image = IconProvider.arrowsSwitch
        smartIV.image = IconProvider.globe

        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.protonExandableButton().cgColor
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
        connectButton.isHidden = viewModel.isTierTooLow
        torIV.isHidden = (viewModel.isTorAvailable && !viewModel.isTierTooLow) || !viewModel.isTorAvailable
        p2pIV.isHidden = (viewModel.isP2PAvailable && !viewModel.isTierTooLow) || !viewModel.isP2PAvailable
        smartIV.isHidden = (viewModel.isSmartAvailable && !viewModel.isTierTooLow) || !viewModel.isSmartAvailable
        addCursorRect(frame, cursor: .pointingHand)
    }
    
    override func mouseExited(with event: NSEvent) {
        expandButton.isEnabled = !disabled
        connectButton.isHidden = !viewModel.isConnected || viewModel.isTierTooLow
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
        
        expandButton.image = viewModel.isOpened ? #imageLiteral(resourceName: "ic_section_arrow_up") : #imageLiteral(resourceName: "ic_section_arrow_down")
        countryLbl.stringValue = viewModel.countryName
        flagIV.image = NSImage.flag(countryCode: viewModel.countryCode)
        connectButton.isConnected = viewModel.isConnected
        connectButton.isHidden = !connectButton.isConnected
        upgradeBtn.isHidden = !viewModel.isTierTooLow || viewModel.underMaintenance
        expandButton.isHidden = viewModel.isTierTooLow || viewModel.underMaintenance
        maintenanceBtn.isHidden = !viewModel.underMaintenance
        connectButton.isHovered = false
        configureFeatures()
        setupAccessibilityCustomActions()
    }
    // MARK: - Actions
    
    @IBAction private func didTapExpandBtn(_ sender: Any) {
        if viewModel.isServerUnderMaintenance || viewModel.isTierTooLow { return }
        viewModel.changeCellState()
        expandButton.image = viewModel.isOpened ? #imageLiteral(resourceName: "ic_section_arrow_up") : #imageLiteral(resourceName: "ic_section_arrow_down")
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
        torIV.isHidden = !viewModel.isTorAvailable || viewModel.isConnected
        p2pIV.isHidden = !viewModel.isP2PAvailable || viewModel.isConnected
        smartIV.isHidden = !viewModel.isSmartAvailable || viewModel.isConnected
    }
    
    // MARK: - Accessibility

    override func accessibilityLabel() -> String? {
        viewModel.accessibilityLabel
    }

    private func setupAccessibilityCustomActions() {
        connectButton.nameForAccessibility = viewModel.countryName
        var actions = [NSAccessibilityCustomAction]()

        if !expandButton.isHidden {
            let name = viewModel.isOpened ? LocalizedString.collapseListOfServers : LocalizedString.expandListOfServers
            actions.append(NSAccessibilityCustomAction(name: name, target: self, selector: #selector(didTapExpandBtn(_:))))
        }
        if upgradeBtn.isHidden {
            let name = connectButton.isConnected ? LocalizedString.disconnect : LocalizedString.connect
            actions.append(NSAccessibilityCustomAction(name: name, target: self, selector: #selector(didTapConnectBtn(_:))))
        } else {
            actions.append(NSAccessibilityCustomAction(name: LocalizedString.upgrade, target: self, selector: #selector(didTapUpgradeBtn(_:))))
        }

        setAccessibilityCustomActions(actions)
    }

    override func accessibilityChildren() -> [Any]? {
        return []
    }
}
