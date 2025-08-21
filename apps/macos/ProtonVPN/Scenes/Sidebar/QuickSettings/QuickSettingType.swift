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

enum ConnectionInfo {
    case connected(portForwardingEnabled: Bool, supportsP2P: Bool, isConnected: Bool)
    case pfError(isConnected: Bool)

    var isConnected: Bool {
        switch self {
        case let .connected(_, _, isConnected):
            isConnected
        case let .pfError(isConnected):
            isConnected
        }
    }
}

// MARK: - Configuration Protocol

protocol QuickSettingConfiguration {
    var type: QuickSettingType { get }
    var presenter: QuickSettingDropdownPresenterProtocol { get }
    var button: QuickSettingButton { get }

    func createViewController() -> QuickSettingDetailViewController
    func handleStateUpdate(connectionInfo: ConnectionInfo) -> QuickSettingState
}

// MARK: - Generic Configuration

struct GenericQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailViewController(presenter)
    }

    func handleStateUpdate(connectionInfo _: ConnectionInfo) -> QuickSettingState {
        .standard
    }
}

// MARK: - NetShield Configuration

struct NetShieldQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType = .netShieldDisplay
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailNetShieldViewController(presenter)
    }

    func handleStateUpdate(connectionInfo: ConnectionInfo) -> QuickSettingState {
        .netShield(statsEnabled: connectionInfo.isConnected)
    }
}

// MARK: - Port Forwarding Configuration

struct PortForwardingQuickSettingConfiguration: QuickSettingConfiguration {
    let type: QuickSettingType = .portForwardingDisplay
    let presenter: QuickSettingDropdownPresenterProtocol
    let button: QuickSettingButton

    func createViewController() -> QuickSettingDetailViewController {
        QuickSettingDetailPFViewController(presenter)
    }

    func handleStateUpdate(connectionInfo: ConnectionInfo) -> QuickSettingState {
        switch connectionInfo {
        case let .connected(portForwardingEnabled, supportsP2P, isConnected):
            switch (isConnected, portForwardingEnabled, supportsP2P) {
            case (true, true, true):
                .portForwarding(.connectedToP2P)
            case (true, true, false):
                .portForwarding(.connectedNotToP2P)
            case (true, false, _):
                .portForwarding(.connectedNoPf)
            case (false, true, _):
                .portForwarding(.notConnected(pfEnabled: true))
            case (false, false, _):
                .portForwarding(.notConnected(pfEnabled: false))
            }
        case .pfError:
            .portForwarding(.error)
        }
    }
}
