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

import AppKit
import LegacyCommon

// MARK: - Supporting Types

enum QuickSettingType: CaseIterable {
    case secureCoreDisplay
    case netShieldDisplay
    case killSwitchDisplay
    case portForwardingDisplay
}

enum QuickSettingState {
    case standard
    case netShield(statsEnabled: Bool)
    case portForwarding(PortForwardingVCState)
}

struct ConnectionInfo {
    let portForwardingEnabled: Bool
    let supportsP2P: Bool
    let isConnected: Bool
}

// MARK: - Configuration Protocol

protocol QuickSettingConfiguration {
    var type: QuickSettingType { get }
    var presenter: QuickSettingDropdownPresenterProtocol { get }
    var button: QuickSettingButton { get }
    var container: NSBox { get }

    func createViewController() -> QuickSettingDetailViewController
    func handleStateUpdate(connectionInfo: ConnectionInfo?) -> QuickSettingState
}

// MARK: - Generic Configuration

struct GenericQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton
    let container: NSBox

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailViewController(presenter)
    }

    func handleStateUpdate(connectionInfo _: ConnectionInfo?) -> QuickSettingState {
        .standard
    }
}

// MARK: - NetShield Configuration

struct NetShieldQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType = .netShieldDisplay
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton
    let container: NSBox

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailNetShieldViewController(presenter)
    }

    func handleStateUpdate(connectionInfo: ConnectionInfo?) -> QuickSettingState {
        .netShield(statsEnabled: connectionInfo?.isConnected ?? false)
    }
}

// MARK: - Port Forwarding Configuration

struct PortForwardingQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType = .portForwardingDisplay
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton
    let container: NSBox

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailPFViewController(presenter)
    }

    func handleStateUpdate(connectionInfo: ConnectionInfo?) -> QuickSettingState {
        guard let connectionInfo else {
            return .portForwarding(.notConnected(pfEnabled: false))
        }

        switch (connectionInfo.isConnected, connectionInfo.portForwardingEnabled, connectionInfo.supportsP2P) {
        case (true, true, true):
            return .portForwarding(.connectedToP2P)
        case (true, true, false):
            return .portForwarding(.connectedNotToP2P)
        case (true, false, _):
            return .portForwarding(.connectedNoPf)
        case (false, true, _):
            return .portForwarding(.notConnected(pfEnabled: true))
        case (false, false, _):
            return .portForwarding(.notConnected(pfEnabled: false))
        }
    }
}
