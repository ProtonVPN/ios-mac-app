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

    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & VpnGatewayFactory

    private let factory: Factory

    @Dependency(\.propertiesManager) private var propertiesManager

    override var learnLink: String {
        VPNLink.killSwitchSupport.urlString
    }

    override var title: String {
        Localizable.killSwitch
    }

    override var descriptionText: String {
        Localizable.quickSettingsKillSwitchDescription
    }

    override var noteText: String {
        Localizable.quickSettingsKillSwitchNote
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingDropdownOption] {
        [killSwitchOff, killSwitchOn]
    }

    // MARK: - Private

    private var killSwitchOff: QuickSettingDropdownOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOff.capitalized
        let icon = Theme.Asset.Icons.switchOff.swiftUIImage
        return QuickSettingDropdownOption(text, icon: icon, active: !active, selectCallback: { dismissCallback in
            self.propertiesManager.killSwitch = false
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                self.vpnGateway.retryConnection()
            }
            dismissCallback()
        })
    }

    private var killSwitchOn: QuickSettingDropdownOption {
        let active = propertiesManager.killSwitch
        let text = Localizable.killSwitch + " " + Localizable.switchSideButtonOn.capitalized
        let icon = Theme.Asset.Icons.switchOn.swiftUIImage

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

        return QuickSettingDropdownOption(text, icon: icon, active: active, selectCallback: { dismissCallback in
            defer { dismissCallback() }

            if self.featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .off, case .disabled = plutonium {
                confirmKillSwitchOn()
                return
            }

            self.alertService.push(alert: KillSwitchConflictAlert(confirmHandler: confirmKillSwitchOn, cancelHandler: nil))
        })
    }
}
