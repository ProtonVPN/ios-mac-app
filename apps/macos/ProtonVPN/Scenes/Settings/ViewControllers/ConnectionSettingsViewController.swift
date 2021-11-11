//
//  ConnectionSettingsViewController.swift
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

final class ConnectionSettingsViewController: NSViewController, ReloadableViewController {
    
    fileprivate enum SwitchButtonOption: Int {
        case killSwitch
    }
    
    @IBOutlet private weak var autoConnectLabel: PVPNTextField!
    @IBOutlet private weak var autoConnectList: HoverDetectionPopUpButton!
    @IBOutlet private weak var autoConnectSeparator: NSBox!
    @IBOutlet private weak var autoConnectInfoIcon: NSImageView!
    
    @IBOutlet private weak var quickConnectLabel: PVPNTextField!
    @IBOutlet private weak var quickConnectList: HoverDetectionPopUpButton!
    @IBOutlet private weak var quickConnectSeparator: NSBox!
    @IBOutlet private weak var quickConnectInfoIcon: NSImageView!
    
    @IBOutlet private weak var protocolView: NSView!
    @IBOutlet private weak var protocolLabel: PVPNTextField!
    @IBOutlet private weak var protocolList: HoverDetectionPopUpButton!
    @IBOutlet private weak var protocolSeparator: NSBox!
    @IBOutlet private weak var protocolInfoIcon: NSImageView!

    @IBOutlet private weak var secureDNSView: NSView!
    @IBOutlet private weak var secureDNSLabel: PVPNTextField!
    @IBOutlet private weak var secureDNSList: HoverDetectionPopUpButton!
    @IBOutlet private weak var secureDNSSeparator: NSBox!
    @IBOutlet private weak var secureDNSInfoIcon: NSImageView!
    
    @IBOutlet private weak var vpnAcceleratorView: NSView!
    @IBOutlet private weak var vpnAcceleratorLabel: PVPNTextField!
    @IBOutlet private weak var vpnAcceleratorButton: SwitchButton!
    @IBOutlet private weak var vpnAcceleratorSeparator: NSBox!
    @IBOutlet private weak var vpnAcceleratorInfoIcon: NSImageView!
    
    @IBOutlet private weak var dnsLeakProtectionLabel: PVPNTextField!
    @IBOutlet private weak var dnsLeakProtectionButton: SwitchButton!
    @IBOutlet private weak var dnsLeakProtectionSeparator: NSBox!
    @IBOutlet private weak var dnsLeakProtectionInfoIcon: NSImageView!
    
    @IBOutlet private weak var alternativeRoutingLabel: PVPNTextField!
    @IBOutlet private weak var alternativeRoutingButton: SwitchButton!
    @IBOutlet private weak var alternativeRoutingSeparator: NSBox!
    @IBOutlet private weak var alternativeRoutingInfoIcon: NSImageView!
    
    @IBOutlet private weak var allowLANLabel: PVPNTextField!
    @IBOutlet private weak var allowLANButton: SwitchButton!
    @IBOutlet private weak var allowLANSeparator: NSBox!
    @IBOutlet private weak var allowLANIcon: NSImageView!
    
    private var viewModel: ConnectionSettingsViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: ConnectionSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ConnectionSettings"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.setViewController(self)
        reloadView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupAutoConnectItem() {
        autoConnectLabel.attributedStringValue = LocalizedString.autoConnect.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        autoConnectList.isBordered = false
        autoConnectList.target = self
        autoConnectList.action = #selector(autoConnectItemSelected)
        
        refreshAutoConnect()
        
        autoConnectInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        autoConnectInfoIcon.toolTip = LocalizedString.autoConnectTooltip
        
        autoConnectSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupQuickConnectItem() {
        quickConnectLabel.attributedStringValue = LocalizedString.quickConnect.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        quickConnectList.isBordered = false
        quickConnectList.target = self
        quickConnectList.action = #selector(quickConnectItemSelected)
        
        refreshQuickConnect()
        
        quickConnectInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        quickConnectInfoIcon.toolTip = LocalizedString.quickConnectTooltip
        
        quickConnectSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupProtocolItem() {
        protocolLabel.attributedStringValue = LocalizedString
            .protocol
            .attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        protocolList.isBordered = false
        protocolList.target = self
        protocolList.action = #selector(protocolItemSelected)
        protocolInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        protocolInfoIcon.toolTip = LocalizedString.smartProtocolDescription
        protocolSeparator.fillColor = .protonLightGrey()
        refreshProtocol()
    }

    private func setupSecureDNSItem() {
        secureDNSLabel.attributedStringValue = LocalizedString
            .secureDnsTitle
            .attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        secureDNSList.isBordered = false
        secureDNSList.target = self
        secureDNSList.action = #selector(secureDNSItemSelected)
        secureDNSInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        secureDNSInfoIcon.toolTip = LocalizedString.secureDnsTitleTooltip
        secureDNSSeparator.fillColor = .protonLightGrey()
        refreshSecureDNS()
    }
    
    private func setupVpnAcceleratorItem() {
        vpnAcceleratorView.isHidden = !viewModel.isAcceleratorFeatureEnabled
        vpnAcceleratorLabel.attributedStringValue = LocalizedString
            .vpnAcceleratorTitle
            .attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        vpnAcceleratorInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        vpnAcceleratorInfoIcon.toolTip = LocalizedString.vpnAcceleratorDescription
            .replacingOccurrences(of: LocalizedString.vpnAcceleratorDescriptionAltLink, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        vpnAcceleratorButton.setState(viewModel.vpnAcceleratorEnabled ? .on : .off)
        vpnAcceleratorButton.delegate = self
        vpnAcceleratorSeparator.fillColor = .protonLightGrey()
        
    }
    
    private func setupDnsLeakProtectionItem() {
        dnsLeakProtectionLabel.attributedStringValue = LocalizedString.dnsLeakProtection.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        dnsLeakProtectionInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        dnsLeakProtectionInfoIcon.toolTip = LocalizedString.dnsLeakProtectionTooltip
        
        dnsLeakProtectionButton.setState(.on)
        dnsLeakProtectionButton.enabled = false
        
        dnsLeakProtectionSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupAlternativeRoutingItem() {
        alternativeRoutingLabel.attributedStringValue = LocalizedString.troubleshootItemAltTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        alternativeRoutingInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        let tooltip = LocalizedString.troubleshootItemAltDescription
            .replacingOccurrences(of: LocalizedString.troubleshootItemAltLink1, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        alternativeRoutingInfoIcon.toolTip = String(tooltip)

        alternativeRoutingButton.setState(viewModel.alternativeRouting ? .on : .off)
        alternativeRoutingButton.delegate = self

        alternativeRoutingSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupAllowLANItem() {
        allowLANLabel.attributedStringValue = LocalizedString.allowLanTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)

        allowLANIcon.image = NSImage(named: NSImage.Name("info_green"))
        allowLANIcon.toolTip = LocalizedString.allowLanInfo

        allowLANButton.setState(viewModel.allowLAN ? .on : .off)
        allowLANButton.delegate = self

        allowLANSeparator.fillColor = .protonLightGrey()
    }
    
    private func refreshAutoConnect() {
        autoConnectList.removeAllItems()
        
        let count = viewModel.autoConnectItemCount
        for index in 0..<count {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.autoConnectItem(for: index)
            autoConnectList.menu?.addItem(menuItem)
        }
        
        autoConnectList.selectItem(at: viewModel.autoConnectProfileIndex)
    }
    
    private func refreshQuickConnect() {
        quickConnectList.removeAllItems()
        
        let count = viewModel.quickConnectItemCount
        for index in 0..<count {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.quickConnectItem(for: index)
            quickConnectList.menu?.addItem(menuItem)
        }
        
        quickConnectList.selectItem(at: viewModel.quickConnectProfileIndex)
    }
    
    private func refreshProtocol() {
        protocolList.removeAllItems()
        let count = viewModel.protocolItemCount
        (0..<count).forEach { index in
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.protocolItem(for: index)
            protocolList.menu?.addItem(menuItem)
        }
        protocolList.selectItem(at: viewModel.protocolProfileIndex)
    }

    private func refreshSecureDNS() {
        secureDNSList.removeAllItems()
        let count = viewModel.secureDnsItemCount
        (0..<count).forEach { index in
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.secureDnsItem(for: index)
            secureDNSList.menu?.addItem(menuItem)
        }
    }
    
    // MARK: - ReloadableViewController
    
    func reloadView() {
        setupView()
        setupAutoConnectItem()
        setupQuickConnectItem()
        setupVpnAcceleratorItem()
        setupSecureDNSItem()
        setupProtocolItem()
        setupDnsLeakProtectionItem()
        setupAlternativeRoutingItem()
        setupAllowLANItem()
    }
    
    // MARK: - Actions
    
    @objc private func autoConnectItemSelected() {
        do {
            try viewModel.setAutoConnect(autoConnectList.indexOfSelectedItem)
        } catch {
            refreshAutoConnect()
        }
    }
    
    @objc private func quickConnectItemSelected() {
        do {
            try viewModel.setQuickConnect(quickConnectList.indexOfSelectedItem)
        } catch {
            refreshQuickConnect()
        }
    }
    
    @objc private func protocolItemSelected() {
        viewModel.setProtocol(protocolList.indexOfSelectedItem)
    }

    @objc private func secureDNSItemSelected() {
        viewModel.setSecureDNS(secureDNSList.indexOfSelectedItem)
    }
}

extension ConnectionSettingsViewController: SwitchButtonDelegate {
    
    public func shouldToggle(_ button: NSButton, to value: ButtonState, completion: @escaping (Bool) -> Void) {
        switch button.superview {
        
        case allowLANButton:
            viewModel.setAllowLANAccess(value == .on, completion: completion)
            
        case vpnAcceleratorButton:
            viewModel.setVpnAccelerator(value == .on, completion: completion)
            
        default:
            completion(true)
        }
    }
    
    func switchButtonClicked(_ button: NSButton) {
        switch button.superview {
        case alternativeRoutingButton:
            viewModel.setAlternatveRouting(alternativeRoutingButton.currentButtonState == .on)
            
        default:
            break // Do nothing
        }
    }
}
