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

import CommonNetworking
import Domain
import LegacyCommon
import Strings
import Theme
import VPNShared

import Dependencies

protocol QuickSettingsDropdownOptionPresenter: AnyObject {
    var title: String! { get }
    var icon: NSImage! { get }
    var active: Bool! { get }
    /// B2C users get upsell modals if their plan doesn't allow a feature.
    var requiresUpdate: Bool! { get }

    var selectCallback: SuccessConfirmationCallback { get }
}

class QuickSettingGenericOption: QuickSettingsDropdownOptionPresenter {
    let title: String!
    let active: Bool!
    let icon: NSImage!
    let requiresUpdate: Bool!
    let selectCallback: SuccessConfirmationCallback

    init(
        _ title: String,
        icon: NSImage = AppTheme.Icon.brandTor,
        active: Bool,
        requiresUpdate: Bool = false,
        selectCallback: @escaping SuccessConfirmationCallback
    ) {
        self.title = title
        self.active = active
        self.icon = icon
        self.requiresUpdate = requiresUpdate
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
        currentPlanName _: String,
        onPotentialHermesConflict: @escaping (@escaping () -> Void) -> Void,
        openUpgradeLink: @escaping () -> Void
    ) {
        var netShieldPropertyProvider = netShieldPropertyProvider

        let text: String = switch level {
        case .level1:
            Localizable.quickSettingsNetshieldOptionLevel1
        case .level2:
            Localizable.quickSettingsNetshieldOptionLevel2
        case .off:
            Localizable.quickSettingsNetshieldOptionOff
        }

        let icon: NSImage = switch level {
        case .level1:
            AppTheme.Icon.shieldHalfFilled
        case .level2:
            AppTheme.Icon.shieldFilled
        case .off:
            AppTheme.Icon.shield
        }

        func changeNetShieldLevel(_ newLevel: NetShieldType) {
            vpnStateConfiguration.getInfo { info in
                switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                case .withConnectionUpdate:
                    netShieldPropertyProvider.netShieldType = newLevel
                    vpnManager.set(netShieldType: newLevel)
                case .withReconnect:
                    netShieldPropertyProvider.netShieldType = newLevel
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                    vpnGateway.reconnect(with: netShieldPropertyProvider.netShieldType)
                case .immediate:
                    netShieldPropertyProvider.netShieldType = newLevel
                }
            }
        }

        super.init(
            text,
            icon: icon,
            active: isActive,
            requiresUpdate: level.isUserTierTooLow(currentUserTier),
            selectCallback: { dismissCallback in
                @Dependency(\.hermesClient) var hermesClient

                guard !level.isUserTierTooLow(currentUserTier) else {
                    openUpgradeLink()
                    dismissCallback()
                    return
                }

                if level != .off, hermesClient.isEnabled().wrappedValue {
                    onPotentialHermesConflict {
                        changeNetShieldLevel(level)
                        hermesClient.setIsEnabled(false)
                        dismissCallback()
                    }
                } else {
                    changeNetShieldLevel(level)
                    dismissCallback()
                }
            }
        )
    }
}

extension NetShieldType {
    var quickSettingsText: String {
        switch self {
        case .level1:
            Localizable.quickSettingsNetshieldOptionLevel1
        case .level2:
            Localizable.quickSettingsNetshieldOptionLevel2
        case .off:
            Localizable.quickSettingsNetshieldOptionOff
        }
    }

    var quickSettingsIcon: NSImage {
        switch self {
        case .level1:
            AppTheme.Icon.shieldHalfFilled
        case .level2:
            AppTheme.Icon.shieldFilled
        case .off:
            AppTheme.Icon.shield
        }
    }
}
