//
//  ServerItemCellView.swift
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

class ServerItemCellView: NSView {
    
    @IBOutlet private weak var loadIcon: ColoredLoadButton!
    @IBOutlet private weak var smartIV: NSImageView!
    @IBOutlet private weak var p2pIV: NSImageView!
    @IBOutlet private weak var torIV: NSImageView!
    @IBOutlet private weak var streamingIV: NSImageView!

    @IBOutlet private weak var serverLbl: NSTextField!
    @IBOutlet private weak var cityLbl: NSTextField!
    @IBOutlet private weak var secureCoreIV: NSImageView!
    @IBOutlet private weak var secureFlagIV: NSImageView!
    @IBOutlet private weak var connectBtn: ConnectButton!
    @IBOutlet private weak var maintenanceIV: NSButton!
    @IBOutlet private weak var upgradeBtn: NSButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer?.backgroundColor = NSColor.protonServerRow().cgColor
        upgradeBtn.stringValue = LocalizedString.upgrade
        maintenanceIV.wantsLayer = true
        maintenanceIV.layer?.cornerRadius = 10
        maintenanceIV.layer?.backgroundColor = NSColor.protonDarkBlueButton().cgColor
        let trackingFrame = NSRect(origin: frame.origin, size: CGSize(width: frame.size.width, height: frame.size.height - 12))
        let trackingArea = NSTrackingArea(rect: trackingFrame, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    private var viewModel: ServerItemViewModel!
    
    var showServerInfo: (() -> Void)?
    
    public var disabled: Bool = false

    override func mouseEntered(with event: NSEvent) {
        if disabled || viewModel.underMaintenance || viewModel.requiresUpgrade {
            mouseExited(with: event)
            return
        }
        cityLbl.isHidden = true
        connectBtn.isHidden = false
    }
    
    override func mouseExited(with event: NSEvent) {
        upgradeBtn.isHidden = !viewModel.requiresUpgrade
        cityLbl.isHidden = viewModel.isConnected || viewModel.requiresUpgrade
        connectBtn.isHidden = !viewModel.isConnected || viewModel.requiresUpgrade
    }
    
    func updateView(withModel viewModel: ServerItemViewModel) {
        self.viewModel = viewModel
        loadIcon.load = viewModel.load
        loadIcon.isHidden = viewModel.underMaintenance
        maintenanceIV.isHidden = !viewModel.underMaintenance
        secureFlagIV.isHidden = !viewModel.isSecureCoreEnabled
        secureCoreIV.isHidden = !viewModel.isSecureCoreEnabled
        serverLbl.stringValue = viewModel.serverName
        cityLbl.stringValue = viewModel.cityName
        connectBtn.isConnected = viewModel.isConnected
        connectBtn.isHidden = !viewModel.isConnected || viewModel.requiresUpgrade
        cityLbl.isHidden = viewModel.isConnected || viewModel.requiresUpgrade
        streamingIV.isHidden = !viewModel.isStreamingAvailable
        torIV.isHidden = !viewModel.isTorAvailable
        p2pIV.isHidden = !viewModel.isP2PAvailable
        smartIV.isHidden = !viewModel.isSmartAvailable
        connectBtn.isHovered = false
        upgradeBtn.isHidden = !viewModel.requiresUpgrade
        setupInfoView()
        
        [loadIcon, maintenanceIV, secureFlagIV, secureCoreIV, serverLbl, cityLbl, torIV, smartIV, p2pIV, streamingIV].forEach {
            $0?.alphaValue = viewModel.alphaForMainElements
        }
                
        if let code = viewModel.entryCountry {
            secureFlagIV.image = NSImage(named: code.lowercased() + "-plain")
        }
        
        setupAccessibility()
    }

    // MARK: - Private functions

    private func setupInfoView() {
        let isUnderMaintenance = viewModel.underMaintenance
        maintenanceIV.isHidden = !isUnderMaintenance
        loadIcon.isHidden = isUnderMaintenance
        if !isUnderMaintenance {
            loadIcon.target = self
            loadIcon.action = #selector(showInfo)
        }
    }
    
    @IBAction func didTapConnectBtn(_ sender: Any) {
        viewModel.connectAction()
    }
    
    @IBAction func didTapUpgradeBtn(_ sender: Any) {
        viewModel.upgradeAction()
    }
    
    @objc private func showInfo() {
        if let showServerInfo = showServerInfo {
            showServerInfo()
        }
    }
    
    // MARK: - Accessibility
    private func setupAccessibility() {
        setAccessibilityLabel(viewModel.accessibilityLabel)
        connectBtn.nameForAccessibility = viewModel.serverName
        connectBtn.setAccessibilityElement(true)
    }
    
    override func accessibilityChildren() -> [Any]? {
        return [connectBtn]
    }
}
