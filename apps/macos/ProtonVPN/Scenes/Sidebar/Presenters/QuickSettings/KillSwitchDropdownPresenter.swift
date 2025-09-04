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

import AppKit
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Sharing
import Strings
import Theme
import VPNAppCore

class KillSwitchDropdownPresenter: QuickSettingDropdownPresenter {
    @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & PropertiesManagerFactory & VpnGatewayFactory

    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()

    override var learnLink: String {
        VPNLink.killSwitchSupport.urlString
    }

    override var title: String {
        Localizable.killSwitch
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingDropdownOptionPresenter] {
        [killSwitchOff, killSwitchOn]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsKillSwitchDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = Localizable.quickSettingsKillSwitchNote.styled(.weak, font: .themeFont(.small), alignment: .left)
        viewController?.dropdownUpgradeButton.isHidden = true

        if VPNFeatureFlagType.portForwarding.enabled {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 4
            viewController?.arrowHorizontalConstraint.constant = oneButtonWidth / 2
        } else {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 3
            viewController?.arrowHorizontalConstraint.constant = oneButtonWidth
        }
    }

    // MARK: - Private

    private var killSwitchOff: QuickSettingGenericOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOff.capitalized
        let icon = AppTheme.Icon.switchOff
        return QuickSettingGenericOption(text, icon: icon, active: !active, selectCallback: { dismissCallback in
            self.propertiesManager.killSwitch = false
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                self.vpnGateway.retryConnection()
            }
            dismissCallback()
        })
    }

    private var killSwitchOn: QuickSettingGenericOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOn.capitalized
        let icon = AppTheme.Icon.switchOn

        @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle

        let confirmKillSwitchOn = {
            self.propertiesManager.killSwitch = true
            self.featurePropertyProvider.setValue(ExcludeLocalNetworks.off)
            $plutonium.withLock { $0 = .disabled(plutonium.mode) }
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                self.vpnGateway.retryConnection()
            }
        }

        return QuickSettingGenericOption(text, icon: icon, active: active, selectCallback: { dismissCallback in
            defer { dismissCallback() }

            if self.featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .off, case .disabled = plutonium {
                confirmKillSwitchOn()
                return
            }

            self.alertService.push(alert: KillSwitchConflictAlert(confirmHandler: confirmKillSwitchOn, cancelHandler: nil))
        })
    }
}
