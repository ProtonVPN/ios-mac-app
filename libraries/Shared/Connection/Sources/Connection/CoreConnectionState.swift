//
//  Created on 20/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CasePaths
import CoreConnection
import Dependencies
import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import ExtensionManager
import struct ExtensionManager.ConnectionData
import Foundation
import LocalAgent

@CasePathable
public enum CoreConnectionState: Equatable, Sendable {
    case unknown
    case disconnected(ConnectionError?)
    case starting
    case connecting(ConnectionData?)
    case connected(ConnectionData, Date, ConnectionDetailsMessage?)
    case disconnecting

    public init(
        tunnelState: ExtensionFeature.State
    ) {
        switch tunnelState {
        case .unknown:
            self = .unknown

        case .invalid:
            // No VPN permission granted yet — from the user's perspective, disconnected
            // TODO: add permissions required error and pass it to .disconnected
            self = .disconnected(nil)

        case .connecting:
            self = .starting

        case .reasserting:
            // We will be using this for peer handover
            // TODO: do we need to add to ConnectionState to model this properly?
            self = .starting

        case .connected(_, nil):
            // Connection data not yet available
            // TODO: Can we provide more information here?
            // providerConfiguration should be up to date (unless peer handover happened while app was in bg?)
            self = .starting

        case let .connected(_, connectionData?):
            // TODO: expand ConnectionData with what's required to show full connection details from ProTUN
            log.debug("Connected with \(optional: connectionData)", category: .connection)
            self = .connected(connectionData, connectionData.connectionDate, nil)

        case .disconnecting:
            self = .disconnecting

        case let .disconnected(possibleTunnelError):
            self = .disconnected(possibleTunnelError.map { .tunnel($0) })
        }
    }

    init(connectionFeatureState: CoreConnectionFeature.State) {
        self.init(tunnelState: connectionFeatureState.tunnel)
    }
}
