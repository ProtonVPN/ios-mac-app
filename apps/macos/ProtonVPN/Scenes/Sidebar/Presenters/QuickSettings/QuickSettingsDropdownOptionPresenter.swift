//
//  QuickSettingsDropdownOptionPresenter.swift
//  ProtonVPN - Created on 10/11/2020.
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

import Domain
import Theme
import Strings
import VPNShared
import LegacyCommon

protocol QuickSettingsDropdownOptionPresenter: AnyObject {
    var title: String! { get }
    var icon: NSImage! { get }
    var active: Bool! { get }
    /// B2C users get upsell modals if their plan doesn't allow a feature.
    var requiresUpdate: Bool! { get }
    /// B2B users should see a "business" badge for disabled features, but no upsell modals.
    var requiresBusinessUpdate: Bool! { get }
    
    var selectCallback: SuccessCallback? { get }
}

class QuickSettingGenericOption: QuickSettingsDropdownOptionPresenter {
    let title: String!
    let active: Bool!
    var icon: NSImage! = AppTheme.Icon.brandTor
    var requiresUpdate: Bool!
    var requiresBusinessUpdate: Bool!
    var selectCallback: (() -> Void)?
    
    init( _ title: String, icon: NSImage, active: Bool, requiresUpdate: Bool = false, requiresBusinessUpdate: Bool = false, selectCallback: SuccessCallback? = nil ) {
        self.title = title
        self.active = active
        self.icon = icon
        self.requiresUpdate = requiresUpdate
        self.requiresBusinessUpdate = requiresBusinessUpdate
        self.selectCallback = selectCallback
    }
}

final class QuickSettingNetshieldOption: QuickSettingGenericOption {
    init(
        level: NetShieldType,
        vpnGateway: VpnGatewayProtocol,
        vpnManager: VpnManagerProtocol,
        netShieldPropertyProvider: NetShieldPropertyProvider,
        vpnStateConfiguration: VpnStateConfiguration,
        isActive: Bool,
        currentUserTier: Int,
        currentPlanName planName: String,
        openUpgradeLink: @escaping () -> Void
    ) {
        var netShieldPropertyProvider = netShieldPropertyProvider
        
        let text: String
        switch level {
        case .level1:
            text = Localizable.quickSettingsNetshieldOptionLevel1
        case .level2:
            text = Localizable.quickSettingsNetshieldOptionLevel2
        case .off:
            text = Localizable.quickSettingsNetshieldOptionOff
        }

        let icon: NSImage
        switch level {
        case .level1:
            icon = AppTheme.Icon.shieldHalfFilled
        case .level2:
            icon = AppTheme.Icon.shieldFilled
        case .off:
            icon = AppTheme.Icon.shield
        }

        super.init(
            text,
            icon: icon,
            active: isActive,
            requiresUpdate: level.isUserTierTooLow(currentUserTier),
            requiresBusinessUpdate: level != .off && planName.isBusinessWithoutNetShield,
            selectCallback: {
                guard !level.isUserTierTooLow(currentUserTier) else {
                    openUpgradeLink()
                    return
                }

                vpnStateConfiguration.getInfo { info in
                    switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                    case .withConnectionUpdate:
                        netShieldPropertyProvider.netShieldType = level
                        vpnManager.set(netShieldType: level)
                    case .withReconnect:
                        netShieldPropertyProvider.netShieldType = level
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                        vpnGateway.reconnect(with: netShieldPropertyProvider.netShieldType)
                    case .immediately:
                        netShieldPropertyProvider.netShieldType = level
                    }
                }
            }
        )
    }
}

extension NetShieldType {
    var quickSettingsText: String {
        switch self {
        case .level1:
            return Localizable.quickSettingsNetshieldOptionLevel1
        case .level2:
            return Localizable.quickSettingsNetshieldOptionLevel2
        case .off:
            return Localizable.quickSettingsNetshieldOptionOff
        }
    }

    var quickSettingsIcon: NSImage {
        switch self {
        case .level1:
            return AppTheme.Icon.shieldHalfFilled
        case .level2:
            return AppTheme.Icon.shieldFilled
        case .off:
            return AppTheme.Icon.shield
        }
    }
}
