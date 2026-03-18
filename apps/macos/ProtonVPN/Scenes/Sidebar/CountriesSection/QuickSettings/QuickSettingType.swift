//
//  Created on 06/08/2025 by Max Kupetskyi.
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

import Domain
import Foundation
import Strings

// MARK: - Supporting Types

enum QuickSettingType: CaseIterable, Hashable {
    case secureCoreDisplay
    case netShieldDisplay
    case killSwitchDisplay
    case portForwardingDisplay

    var title: String {
        switch self {
        case .secureCoreDisplay:
            Localizable.secureCore
        case .netShieldDisplay:
            Localizable.netshieldTitle
        case .killSwitchDisplay:
            Localizable.killSwitch
        case .portForwardingDisplay:
            Localizable.portForwarding
        }
    }

    var description: String {
        switch self {
        case .secureCoreDisplay:
            Localizable.quickSettingsSecureCoreDescription
        case .netShieldDisplay:
            Localizable.quickSettingsNetShieldDescription
        case .killSwitchDisplay:
            Localizable.quickSettingsKillSwitchDescription
        case .portForwardingDisplay:
            Localizable.quickSettingsPortForwardingDescription
        }
    }

    var note: String? {
        switch self {
        case .secureCoreDisplay:
            Localizable.quickSettingsSecureCoreNote
        case .netShieldDisplay:
            Localizable.quickSettingsNetShieldNote
        case .killSwitchDisplay:
            Localizable.quickSettingsKillSwitchNote
        case .portForwardingDisplay:
            nil
        }
    }

    var learnMoreLink: VPNLink {
        switch self {
        case .secureCoreDisplay:
            VPNLink.learnMore
        case .netShieldDisplay:
            VPNLink.netshieldSupport
        case .killSwitchDisplay:
            VPNLink.killSwitchSupport
        case .portForwardingDisplay:
            VPNLink.portForwardingSupport
        }
    }
}

enum PortForwardingVCState: Equatable {
    case notConnected(pfEnabled: Bool)
    case loading
    case connectedNoPf
    case connectedToP2P
    case connectedNotToP2P
    case error
}

enum QuickSettingState {
    case standard
    case netShield(statsEnabled: Bool)
    case portForwarding(PortForwardingVCState)
}

enum ConnectionInfo: Equatable {
    case portForwardingStatus(enabled: Bool, supportsP2P: Bool, isConnected: Bool)
    case pfError(isConnected: Bool)

    var isConnected: Bool {
        switch self {
        case let .portForwardingStatus(_, _, isConnected):
            isConnected
        case let .pfError(isConnected):
            isConnected
        }
    }
}
