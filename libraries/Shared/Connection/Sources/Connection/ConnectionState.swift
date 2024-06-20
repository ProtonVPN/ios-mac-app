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

import Foundation

import CasePaths
import Dependencies

import ConnectionFoundations
import ExtensionManager
import LocalAgent
import struct Domain.Server

@CasePathable
public enum ConnectionState: Equatable, Sendable {
    case disconnected(ConnectionError?)
    case connecting
    case connected(Server)
    case disconnecting

    public init(
        tunnelState: ExtensionFeature.State,
        localAgentState: LocalAgentFeature.State
    ) {
        if case .disconnected(let tunnelConnectionError) = tunnelState, let tunnelConnectionError {
            self = .disconnected(.tunnel(tunnelConnectionError))
            return
        }

        if case .disconnected(let agentConnectionError) = localAgentState, let agentConnectionError {
            self = .disconnected(.agent(agentConnectionError))
            return
        }

        switch (tunnelState, localAgentState) {
        case (.connected(let logicalServerInfo), .connected):
            @Dependency(\.serverIdentifier) var serverIdentifier
            guard let server = serverIdentifier.fullServerInfo(logicalServerInfo) else {
                assertionFailure("Unknown server")
                self = .disconnected(.serverMissing)
                return
            }
            self = .connected(server)

        case (.connected, _), (.connecting, _):
            self = .connecting

        case (.disconnecting, _):
            self = .disconnecting

        case (.disconnected, _):
            // Disconnected with errors is already covered before the switch.
            self = .disconnected(nil)
        }
    }
}
