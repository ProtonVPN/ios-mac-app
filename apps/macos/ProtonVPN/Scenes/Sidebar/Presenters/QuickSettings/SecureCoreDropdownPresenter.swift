//
//  SecureCoreDropdownPresenter.swift
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

import AppKit
import Domain
import Foundation
import LegacyCommon
import Strings
import Theme
import VPNAppCore

class SecureCoreDropdownPresenter: QuickSettingDropdownPresenter {
    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & VpnGatewayFactory

    private let factory: Factory

    @Dependency(\.propertiesManager) private var propertiesManager

    override var alert: UpsellAlert {
        SecureCoreUpsellAlert()
    }

    override var title: String {
        Localizable.secureCore
    }

    override var learnLink: String {
        VPNLink.learnMore.urlString
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingDropdownOptionPresenter] {
        [secureCoreOff, secureCoreOn]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsSecureCoreDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = Localizable.quickSettingsSecureCoreNote.styled(.weak, font: .themeFont(.small), alignment: .left)

        if VPNFeatureFlagType.portForwarding.enabled {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 4
            viewController?.arrowHorizontalConstraint.constant = -(oneButtonWidth + oneButtonWidth / 2)
        } else {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 3
            viewController?.arrowHorizontalConstraint.constant = -oneButtonWidth
        }
    }

    // MARK: - Private

    private var secureCoreOff: QuickSettingGenericOption {
        let active = !propertiesManager.secureCoreToggle
        let text = Localizable.secureCore + " " + Localizable.switchSideButtonOff.capitalized
        let icon = AppTheme.Icon.lock
        return QuickSettingGenericOption(
            text,
            icon: icon,
            active: active,
            requiresUpdate: requiresUpdate(secureCore: false),
            selectCallback: { dismissCallback in
                self.vpnGateway.changeActiveServerType(.standard)
                self.displayReconnectionFeedback()
                dismissCallback()
            }
        )
    }

    private var secureCoreOn: QuickSettingGenericOption {
        let active = propertiesManager.secureCoreToggle
        let text = Localizable.secureCore + " " + Localizable.switchSideButtonOn.capitalized
        let icon = AppTheme.Icon.locks
        return QuickSettingGenericOption(
            text,
            icon: icon,
            active: active,
            requiresUpdate: requiresUpdate(secureCore: true),
            selectCallback: { dismissCallback in
                guard !self.requiresUpdate(secureCore: true) else {
                    self.presentUpsellAlert()
                    dismissCallback()
                    return
                }
                let onActivate = { [weak self] in
                    self?.vpnGateway.changeActiveServerType(.secureCore)
                    self?.displayReconnectionFeedback()
                    dismissCallback()
                }
                guard self.propertiesManager.discourageSecureCore == false else {
                    self.presentDiscourageSecureCoreAlert(
                        onDontShowAgain: { dontShow in
                            self.propertiesManager.discourageSecureCore = !dontShow
                            dismissCallback()
                        },
                        onActivate: onActivate,
                        onDismiss: dismissCallback
                    )
                    return
                }
                onActivate()
            }
        )
    }

    private func requiresUpdate(secureCore isOn: Bool) -> Bool {
        isOn
            ? currentUserTier.isFreeTier
            : false
    }

    private var currentUserTier: Int {
        (try? vpnGateway.userTier()) ?? .freeTier
    }
}
