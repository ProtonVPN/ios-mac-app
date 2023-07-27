//
//  KillSwitchDropdownPresenter.swift
//  ProtonVPN - Created on 04/11/2020.
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

import Foundation
import LegacyCommon
import AppKit
import Theme
import Strings

class KillSwitchDropdownPresenter: QuickSettingDropdownPresenter {
    
    typealias Factory = VpnGatewayFactory & PropertiesManagerFactory & AppStateManagerFactory & CoreAlertServiceFactory & ModelIdCheckerFactory
    
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var modelIdChecker: ModelIdCheckerProtocol = factory.makeModelIdChecker()
    
    override var learnLink: String {
        return CoreAppConstants.ProtonVpnLinks.killSwitchSupport
    }
    
    override var title: String! {
        return Localizable.killSwitch
    }
    
    init( _ factory: Factory ) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }
    
    override var options: [QuickSettingsDropdownOptionPresenter] {
        return [killSwitchOff, killSwitchOn]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsKillSwitchDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = Localizable.quickSettingsKillSwitchNote.styled(.weak, font: .themeFont(.small), alignment: .left)
        viewController?.dropdownUpgradeButton.isHidden = true
        if propertiesManager.featureFlags.netShield {
            viewController?.arrowHorizontalConstraint.constant = ((AppConstants.Windows.sidebarWidth - 18) / 3) - 7
        } else {
            viewController?.arrowHorizontalConstraint.constant = ((AppConstants.Windows.sidebarWidth - 18) / 5) + 12
        }
    }
    
    // MARK: - Private
    
    private var killSwitchOff: QuickSettingGenericOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOff.capitalized
        let icon = AppTheme.Icon.switchOff
        return QuickSettingGenericOption(text, icon: icon, active: !active, selectCallback: {
            self.propertiesManager.killSwitch = false
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                self.vpnGateway.retryConnection()
            }
        })
    }
    
    private var killSwitchOn: QuickSettingGenericOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOn.capitalized
        let icon = AppTheme.Icon.switchOn

        let connect = {
            self.propertiesManager.killSwitch = true
            self.propertiesManager.excludeLocalNetworks = false
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                self.vpnGateway.retryConnection()
            }
        }

        let connectAfterLocalNetworkWarning = {
            guard self.propertiesManager.excludeLocalNetworks else {
                connect()
                return
            }

            self.alertService.push(alert: TurnOnKillSwitchAlert(confirmHandler: connect, cancelHandler: nil))
        }

        return QuickSettingGenericOption(text, icon: icon, active: active, selectCallback: {
            guard self.modelIdChecker.isT2Mac else {
                connectAfterLocalNetworkWarning()
                return
            }

            log.info("User receiving T2 warning after attempting to enable Kill Switch",
                     category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
            self.alertService.push(alert: NEKSOnT2Alert(
                killSwitchOffHandler: {
                    log.info("User has disabled Kill Switch after receiving T2 warning",
                             category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                },
                connectAnywayHandler: {
                    log.info("User has proceeded with enabling Kill Switch on a T2 device. Fireworks shall ensue.",
                             category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                    connectAfterLocalNetworkWarning()
                })
            )
        })
    }
}
