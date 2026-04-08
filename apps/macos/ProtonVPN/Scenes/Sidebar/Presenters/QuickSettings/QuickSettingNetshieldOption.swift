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

import Dependencies
import Domain
import LegacyCommon
import Strings
import SwiftUI
import Theme

extension QuickSettingDropdownOption {
    static func netshield(
        level: NetShieldType,
        vpnGateway: VpnGatewayProtocol,
        vpnManager: VpnManagerProtocol,
        vpnStateConfiguration: VpnStateConfiguration,
        isActive: Bool,
        currentUserTier: Int,
        onPotentialHermesConflict: @escaping (@escaping () -> Void) -> Void,
        openUpgradeLink: @escaping () -> Void
    ) -> QuickSettingDropdownOption {
        let text: String = switch level {
        case .level1:
            Localizable.quickSettingsNetshieldOptionLevel1
        case .level2:
            Localizable.quickSettingsNetshieldOptionLevel2
        case .off:
            Localizable.quickSettingsNetshieldOptionOff
        }

        let icon: Image = switch level {
        case .level1:
            Theme.Asset.Icons.shieldHalfFilled.swiftUIImage
        case .level2:
            Theme.Asset.Icons.shieldFilled.swiftUIImage
        case .off:
            Theme.Asset.Icons.shield.swiftUIImage
        }

        func changeNetShieldLevel(_ newLevel: NetShieldType) {
            @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider

            vpnStateConfiguration.getInfoSync { info in
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

        return QuickSettingDropdownOption(
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
