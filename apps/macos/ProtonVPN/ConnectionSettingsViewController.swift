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

class ConnectionSettingsViewController: NSViewController, ReloadableViewController {
    
    fileprivate enum SwitchButtonOption: Int {
        case killSwitch
    }
    
    @IBOutlet weak var autoConnectLabel: PVPNTextField!
    @IBOutlet weak var autoConnectList: HoverDetectionPopUpButton!
    @IBOutlet weak var autoConnectSeparator: NSBox!
    @IBOutlet weak var autoConnectInfoIcon: NSImageView!
    
    @IBOutlet weak var quickConnectLabel: PVPNTextField!
    @IBOutlet weak var quickConnectList: HoverDetectionPopUpButton!
    @IBOutlet weak var quickConnectSeparator: NSBox!
    @IBOutlet weak var quickConnectInfoIcon: NSImageView!
    
    @IBOutlet weak var killSwitchLabel: PVPNTextField!
    @IBOutlet weak var killSwitchButton: SwitchButton!
    @IBOutlet weak var killSwitchSeparator: NSBox!
    @IBOutlet weak var killSwitchInfoIcon: NSImageView!
    
    @IBOutlet weak var protocolView: NSView!
    @IBOutlet weak var protocolLabel: PVPNTextField!
    @IBOutlet weak var protocolList: HoverDetectionPopUpButton!
    @IBOutlet weak var protocolSeparator: NSBox!
    @IBOutlet weak var protocolInfoIcon: NSImageView!

    @IBOutlet weak var dnsLeakProtectionLabel: PVPNTextField!
    @IBOutlet weak var dnsLeakProtectionButton: SwitchButton!
    @IBOutlet weak var dnsLeakProtectionSeparator: NSBox!
    @IBOutlet weak var dnsLeakProtectionInfoIcon: NSImageView!
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(killSwitchChanged(_:)), name: viewModel.propertiesManager.killSwitchNotification, object: nil)
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
    
    private func setupKillSwitchItem() {
        killSwitchLabel.attributedStringValue = LocalizedString.killSwitch.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)

        killSwitchButton.setState(viewModel.killSwitch ? .on : .off)
        killSwitchButton.buttonView?.tag = SwitchButtonOption.killSwitch.rawValue
        killSwitchButton.delegate = self
        
        killSwitchInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        killSwitchInfoIcon.toolTip = LocalizedString.killSwitchTooltip
        
        killSwitchSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupProtocolItem() {
        protocolLabel.attributedStringValue = LocalizedString
            .protocolLabel
            .attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        protocolList.isBordered = false
        protocolList.target = self
        protocolList.action = #selector(protocolItemSelected)
        protocolInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        protocolInfoIcon.toolTip = LocalizedString.openVPNSettingsDescription
        protocolSeparator.fillColor = .protonLightGrey()
        refreshProtocol()
    }
    
    @objc private func killSwitchChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.killSwitchButton.setState(self.viewModel.killSwitch ? .on : .off)
        }
    }
    
    private func setupDnsLeakProtectionItem() {
        dnsLeakProtectionLabel.attributedStringValue = LocalizedString.dnsLeakProtection.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        dnsLeakProtectionInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        dnsLeakProtectionInfoIcon.toolTip = LocalizedString.dnsLeakProtectionTooltip
        
        dnsLeakProtectionButton.setState(.on)
        dnsLeakProtectionButton.enabled = false
        
        dnsLeakProtectionSeparator.fillColor = .protonLightGrey()
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
    
    // MARK: - ReloadableViewController
    
    func reloadView() {
        setupView()
        setupAutoConnectItem()
        setupQuickConnectItem()
        setupKillSwitchItem()
        setupProtocolItem()
        setupDnsLeakProtectionItem()
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
}

extension ConnectionSettingsViewController: SwitchButtonDelegate {
    
    func switchButtonClicked(_ button: NSButton) {
        switch button.tag {
        case SwitchButtonOption.killSwitch.rawValue:
            viewModel.setKillSwitch(killSwitchButton.currentButtonState == .on)
        default:
            break
        }
    }
}
