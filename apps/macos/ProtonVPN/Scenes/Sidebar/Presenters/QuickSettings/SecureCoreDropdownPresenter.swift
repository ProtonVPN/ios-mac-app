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

    override var descriptionText: String {
        Localizable.quickSettingsSecureCoreDescription
    }

    override var noteText: String {
        Localizable.quickSettingsSecureCoreNote
    }

    override var learnLink: String {
        VPNLink.learnMore.urlString
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingDropdownOption] {
        [secureCoreOff, secureCoreOn]
    }

    // MARK: - Private

    private var secureCoreOff: QuickSettingDropdownOption {
        let active = !propertiesManager.secureCoreToggle
        let text = Localizable.secureCore + " " + Localizable.switchSideButtonOff.capitalized
        let icon = Theme.Asset.Icons.lock.swiftUIImage
        return QuickSettingDropdownOption(
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

    private var secureCoreOn: QuickSettingDropdownOption {
        let active = propertiesManager.secureCoreToggle
        let text = Localizable.secureCore + " " + Localizable.switchSideButtonOn.capitalized
        let icon = Theme.Asset.Icons.locks.swiftUIImage
        return QuickSettingDropdownOption(
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
