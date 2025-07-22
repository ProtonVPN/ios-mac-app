//
//  Created on 22/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import AppKit
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Sharing
import Strings
import Theme
import VPNAppCore

final class PortForwardingDropdownPresenter: QuickSettingDropdownPresenter {
    @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & ModelIdCheckerFactory & PropertiesManagerFactory & VpnGatewayFactory

    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var modelIdChecker: ModelIdCheckerProtocol = factory.makeModelIdChecker()

    override var learnLink: String {
        VPNLink.portForwardingSupport.urlString
    }

    override var title: String! {
        Localizable.portForwarding
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingsDropdownOptionPresenter] {
        [portForwardingOff, portForwardingOn]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsPortForwardingDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.stringValue = ""
        viewController?.dropdownUpgradeButton.isHidden = true

        if propertiesManager.featureFlags.netShield {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 4
            viewController?.arrowHorizontalConstraint.constant = (oneButtonWidth + oneButtonWidth / 2)
        } else {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 3
            viewController?.arrowHorizontalConstraint.constant = oneButtonWidth
        }
    }

    // MARK: - Private

    private var portForwardingOff: QuickSettingGenericOption {
        let active = propertiesManager.portForwarding
        let text = Localizable.portForwarding + " " + Localizable.switchSideButtonOff.capitalized
        let icon = AppTheme.Icon.arrowUpBounceLeft
        return QuickSettingGenericOption(text, icon: icon, active: !active, selectCallback: { _ in
            self.propertiesManager.portForwarding = false
            if self.vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
//                self.vpnGateway.retryConnection()
            }
//            dismissCallback()
        })
    }

    private var portForwardingOn: QuickSettingGenericOption {
        let active = propertiesManager.portForwarding
        let text = Localizable.portForwarding + " " + Localizable.switchSideButtonOn.capitalized
        let icon = AppTheme.Icon.arrowsSwitch
        return QuickSettingGenericOption(
            text,
            icon: icon,
            active: active,
            requiresUpdate: requiresUpdate(portForwarding: true),
            selectCallback: { dismissCallback in
                guard !self.requiresUpdate(portForwarding: true) else {
                    self.presentUpsellAlert()
                    dismissCallback()
                    return
                }
                self.propertiesManager.portForwarding = true
            }
        )
    }

    private func requiresUpdate(portForwarding isOn: Bool) -> Bool {
        isOn
            ? currentUserTier.isFreeTier
            : false
    }

    private var currentUserTier: Int {
        (try? vpnGateway.userTier()) ?? .freeTier
    }
}
