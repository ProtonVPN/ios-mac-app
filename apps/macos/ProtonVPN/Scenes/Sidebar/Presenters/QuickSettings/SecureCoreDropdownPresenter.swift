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

import Foundation
import LegacyCommon
import AppKit
import Theme
import Strings
import VPNAppCore
import Domain

class SecureCoreDropdownPresenter: QuickSettingDropdownPresenter {
    typealias Factory = VpnGatewayFactory & PropertiesManagerFactory & AppStateManagerFactory & CoreAlertServiceFactory
    
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    override var alert: UpsellAlert {
        SecureCoreUpsellAlert()
    }
    
    override var title: String! {
        Localizable.secureCore
    }
    
    override var learnLink: String {
        VPNLink.learnMore.urlString
    }
    
    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }
    
    override var options: [QuickSettingsDropdownOptionPresenter] {
        [secureCoreOff, secureCoreOn]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsSecureCoreDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = Localizable.quickSettingsSecureCoreNote.styled(.weak, font: .themeFont(.small), alignment: .left)
        if propertiesManager.featureFlags.netShield {
            viewController?.arrowHorizontalConstraint.constant = -((AppConstants.Windows.sidebarWidth - 18) / 3) + 7
        } else {
            viewController?.arrowHorizontalConstraint.constant = -((AppConstants.Windows.sidebarWidth - 18) / 5) - 12
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
