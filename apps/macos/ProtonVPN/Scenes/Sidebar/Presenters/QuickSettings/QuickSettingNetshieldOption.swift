//
//  Created on 23/07/2025 by Max Kupetskyi.
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

import Cocoa
import Dependencies
import Domain
import LegacyCommon
import Strings
import Theme

final class QuickSettingNetshieldOption: QuickSettingGenericOption {
    init(
        level: NetShieldType,
        vpnGateway: VpnGatewayProtocol,
        vpnManager: VpnManagerProtocol,
        vpnStateConfiguration: VpnStateConfiguration,
        isActive: Bool,
        currentUserTier: Int,
        currentPlanName _: String,
        onPotentialHermesConflict: @escaping (@escaping () -> Void) -> Void,
        openUpgradeLink: @escaping () -> Void
    ) {
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
            @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider

            vpnStateConfiguration.getInfo { info in
                switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                case .withConnectionUpdate:
                    netShieldPropertyProvider.setNetShieldType(newLevel)
                    vpnManager.set(netShieldType: newLevel)
                case .withReconnect:
                    netShieldPropertyProvider.setNetShieldType(newLevel)
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                    vpnGateway.reconnect(with: netShieldPropertyProvider.getNetShieldType())
                case .immediate:
                    netShieldPropertyProvider.setNetShieldType(newLevel)
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
