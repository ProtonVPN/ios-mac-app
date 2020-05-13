//
//  GeneralViewController.swift
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

class GeneralSettingsViewController: NSViewController {
    
    fileprivate enum SwitchButtonOption: Int {
        case rememberLogin
        case startOnBoot
        case startMinimized
        case systemNotifications
        case earlyAccess
        case unprotectedNetworkNotifications
    }
    
    @IBOutlet weak var rememberLoginLabel: PVPNTextField!
    @IBOutlet weak var rememberLoginButton: SwitchButton!
    @IBOutlet weak var rememberLoginSeparator: NSBox!
    
    @IBOutlet weak var startOnBootLabel: PVPNTextField!
    @IBOutlet weak var startOnBootButton: SwitchButton!
    @IBOutlet weak var startOnBootSeparator: NSBox!
    
    @IBOutlet weak var startMinimizedLabel: PVPNTextField!
    @IBOutlet weak var startMinimizedButton: SwitchButton!
    @IBOutlet weak var startMinimizedSeperator: NSBox!
    
    @IBOutlet weak var systemNotificationsLabel: PVPNTextField!
    @IBOutlet weak var systemNotificationsButton: SwitchButton!
    @IBOutlet weak var systemNotificationsSeparator: NSBox!
    
    @IBOutlet weak var earlyAccessLabel: PVPNTextField!
    @IBOutlet weak var earlyAccessButton: SwitchButton!
    @IBOutlet weak var earlyAccessSeparator: NSBox!
    @IBOutlet weak var earlyAccessInfoIcon: NSImageView!

    @IBOutlet weak var unprotectedNetworkLabel: PVPNTextField!
    @IBOutlet weak var unprotectedNetworkInfoIcon: NSImageView!
    @IBOutlet weak var unprotectedNetworkSeparator: NSBox!
    @IBOutlet weak var unprotectedNetworkButton: SwitchButton!

    fileprivate var viewModel: GeneralViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: GeneralViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("General"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupRememberLoginItem()
        setupStartOnBootItem()
        setupStartMinimizedItem()
        setupSystemNotificationsItem()
        setupEarlyAccessItem()
        setupUnprotectedNetworkItem()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupRememberLoginItem() {
        rememberLoginLabel.attributedStringValue = LocalizedString.rememberLogin.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        rememberLoginButton.setState(viewModel.rememberLogin ? .on : .off)
        rememberLoginButton.buttonView?.tag = SwitchButtonOption.rememberLogin.rawValue
        rememberLoginButton.delegate = self
        
        rememberLoginSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupStartOnBootItem() {
        startOnBootLabel.attributedStringValue = LocalizedString.startOnBoot.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        startOnBootButton.setState(viewModel.startOnBoot ? .on : .off)
        startOnBootButton.buttonView?.tag = SwitchButtonOption.startOnBoot.rawValue
        startOnBootButton.delegate = self
        
        startOnBootSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupStartMinimizedItem() {
        startMinimizedLabel.attributedStringValue = LocalizedString.startMinimized.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        startMinimizedButton.setState(viewModel.startMinimized ? .on : .off)
        startMinimizedButton.buttonView?.tag = SwitchButtonOption.startMinimized.rawValue
        startMinimizedButton.delegate = self
        
        startMinimizedSeperator.fillColor = .protonLightGrey()
    }
    
    private func setupSystemNotificationsItem() {
        systemNotificationsLabel.attributedStringValue = LocalizedString.systemNotifications.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        systemNotificationsButton.setState(viewModel.systemNotifications ? .on : .off)
        systemNotificationsButton.buttonView?.tag = SwitchButtonOption.systemNotifications.rawValue
        systemNotificationsButton.delegate = self
        
        systemNotificationsSeparator.fillColor = .protonLightGrey()
    }
    
    private func setupEarlyAccessItem() {
        earlyAccessLabel.attributedStringValue = LocalizedString.earlyAccess.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        earlyAccessButton.setState(viewModel.earlyAccess ? .on : .off)
        earlyAccessButton.buttonView?.tag = SwitchButtonOption.earlyAccess.rawValue
        earlyAccessButton.delegate = self
        
        earlyAccessInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        earlyAccessInfoIcon.toolTip = LocalizedString.earlyAccessTooltip
        
        earlyAccessSeparator.fillColor = .protonLightGrey()
    }

    private func setupUnprotectedNetworkItem() {
        unprotectedNetworkLabel.attributedStringValue = LocalizedString.unprotectedNetwork.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)

        unprotectedNetworkButton.setState(viewModel.unprotectedNetworkNotifications ? .on : .off)
        unprotectedNetworkButton.buttonView?.tag = SwitchButtonOption.unprotectedNetworkNotifications.rawValue
        unprotectedNetworkButton.delegate = self

        unprotectedNetworkInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        unprotectedNetworkInfoIcon.toolTip = LocalizedString.unprotectedNetworkTooltip

        unprotectedNetworkSeparator.fillColor = .protonLightGrey()
    }
}

extension GeneralSettingsViewController: SwitchButtonDelegate {
    
    func switchButtonClicked(_ button: NSButton) {
        switch button.tag {
        case SwitchButtonOption.rememberLogin.rawValue:
            viewModel.setRememberLogin(rememberLoginButton.currentButtonState == .on)
        case SwitchButtonOption.startOnBoot.rawValue:
            viewModel.setStartOnBoot(startOnBootButton.currentButtonState == .on)
        case SwitchButtonOption.startMinimized.rawValue:
            viewModel.setStartMinimized(startMinimizedButton.currentButtonState == .on)
        case SwitchButtonOption.systemNotifications.rawValue:
            viewModel.setSystemNotifications(systemNotificationsButton.currentButtonState == .on)
        case SwitchButtonOption.earlyAccess.rawValue:
            viewModel.setEarlyAccess(earlyAccessButton.currentButtonState == .on)
        case SwitchButtonOption.unprotectedNetworkNotifications.rawValue:
            viewModel.setUnprotectedNetworkNotifications(unprotectedNetworkButton.currentButtonState == .on)
        default:
            break
        }
    }
}
