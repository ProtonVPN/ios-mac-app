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

protocol ServerItemCellViewDelegate: AnyObject {
    func userDidRequestStreamingInfo(server: ServerItemViewModel)
    func userDidClickOnPartnerIcon(partner: Partner)
}

final class ServerItemCellView: NSView {
    
    @IBOutlet private weak var loadIcon: ColoredLoadButton!
    @IBOutlet private weak var smartIV: NSImageView!
    @IBOutlet private weak var p2pIV: NSImageView!
    @IBOutlet private weak var torIV: NSImageView!
    @IBOutlet private weak var streamingIV: NSButton!
    @IBOutlet private weak var dwButton: NSButton!

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
        layer?.backgroundColor = .cgColor(.background, .weak)
        upgradeBtn.stringValue = LocalizedString.upgrade

        let imageMargin = 8
        maintenanceIV.wantsLayer = true
        maintenanceIV.layer?.cornerRadius = maintenanceIV.bounds.height / 2
        maintenanceIV.layer?.backgroundColor = .clear
        maintenanceIV.layer?.borderColor = .cgColor(.icon, .weak)
        maintenanceIV.layer?.borderWidth = 2.0
        maintenanceIV.image = AppTheme.Icon.wrench
            .colored(.weak)
            .resize(newWidth: Int(maintenanceIV.bounds.width) - imageMargin,
                    newHeight: Int(maintenanceIV.bounds.height) - imageMargin)

        streamingIV.image = AppTheme.Icon.play.colored(.weak)
        torIV.image = AppTheme.Icon.brandTor.colored(.weak)
        p2pIV.image = AppTheme.Icon.arrowsSwitch.colored(.weak)
        smartIV.image = AppTheme.Icon.globe.colored(.weak)
        secureCoreIV.image = AppTheme.Icon.chevronsRight.colored([.interactive, .strong])
        dwButton.image = Bundle.vpnCore.image(forResource: .init("Deutsche-Welle-medium"))

        let trackingFrame = NSRect(origin: frame.origin, size: CGSize(width: frame.size.width, height: frame.size.height - 12))
        let trackingArea = NSTrackingArea(rect: trackingFrame,
                                          options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    private var viewModel: ServerItemViewModel!
    
    var disabled: Bool = false

    weak var delegate: ServerItemCellViewDelegate?

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
        dwButton.isHidden = viewModel.partner == nil
        connectBtn.isHovered = false
        upgradeBtn.isHidden = !viewModel.requiresUpgrade
        setupInfoView()
        
        [loadIcon, maintenanceIV, secureFlagIV, secureCoreIV, serverLbl, cityLbl, torIV, smartIV, p2pIV, streamingIV, dwButton].forEach {
            $0?.alphaValue = viewModel.alphaForMainElements
        }
                
        if let code = viewModel.entryCountry {
            secureFlagIV.image = AppTheme.Icon.flag(countryCode: code)
        }
        
        setupAccessibility()
    }

    // MARK: - Private functions

    private func setupInfoView() {
        let isUnderMaintenance = viewModel.underMaintenance
        maintenanceIV.isHidden = !isUnderMaintenance
        loadIcon.isHidden = isUnderMaintenance
    }
    
    @IBAction private func didTapConnectBtn(_ sender: Any) {
        viewModel.connectAction()
    }
    
    @IBAction private func didTapUpgradeBtn(_ sender: Any) {
        viewModel.upgradeAction()
    }

    @IBAction private func didTapStreaming(_ sender: Any) {
        delegate?.userDidRequestStreamingInfo(server: viewModel)
    }

    @IBAction private func didTapPartner(_ sender: Any) {
        guard let partner = viewModel.partner else { return }
        delegate?.userDidClickOnPartnerIcon(partner: partner)
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
