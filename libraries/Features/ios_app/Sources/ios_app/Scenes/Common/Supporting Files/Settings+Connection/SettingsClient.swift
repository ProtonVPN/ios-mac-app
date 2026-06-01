//
//  Created on 22/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Connection
import Dependencies
import Settings
import Sharing
import VPNAppCore

extension SettingsClient: @retroactive DependencyKey {
    public static let liveValue = SettingsClient(
        isActive: {
            @Shared(.connectionState) var connectionState
            return !(connectionState.is(\.disconnected) || connectionState.is(\.resolving))
        },
        featureChangeAvailability: { feature in
            @Shared(.connectionState) var connectionState

            if connectionState.is(\.disconnected) {
                return .immediate
            }

            switch feature {
            case .tunnel:
                return .withReconnect

            case .agent:
                // We only support WG on iOS, so we can always update features via local agent
                return .withConnectionUpdate
            }
        },
        protocolChangeAvailability: { _ in
            @Shared(.connectionState) var connectionState
            switch connectionState {
            case .disconnected, .disconnecting:
                return .immediate

            case .resolving:
                log.warning("Protocol change availability requested before connection layer state was resolved")
                return .withReconnect

            case .connecting(.unresolved):
                return .withReconnect

            case let .connected(_, server, _, _), let .connecting(.resolved(_, server)):
                @Shared(.smartProtocolConfig) var smartProtocolConfig
                let supportedProtocols = smartProtocolConfig.supportedProtocols
                let serverSupportsNewProtocol = server.endpoint.supports(protocolSet: .init(vpnProtocols: supportedProtocols))
                return serverSupportsNewProtocol ? .withReconnect : .protocolUnavailable
            }
        },
        disconnect: {
            @Dependency(\.connectionCommandClient) var connectionCommandClient
            connectionCommandClient.send(.disconnect(.auto))
        },
        reconnect: { _ in
            @Dependency(\.connectionCommandClient) var connectionCommandClient
            connectionCommandClient.send(.reconnect(nil)) // Caused by feature change
        },
        update: { agentFeatures in
            @Dependency(\.connectionCommandClient) var connectionCommandClient
            connectionCommandClient.send(.applySettings(agentFeatures))
        }
    )
}
