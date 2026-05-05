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
import CertificateAuthentication
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
        tunnelState: ExtensionFeature.State,
        certAuthState: CertificateAuthenticationFeature.State,
        localAgentState: LocalAgentFeature.State
    ) {
        switch (tunnelState, localAgentState) {
        case (.unknown, _):
            self = .unknown

        case (.invalid, _):
            // No VPN permission granted yet — from the user's perspective, disconnected
            self = .disconnected(nil)

        case (.connecting, _), (.reasserting, _):
            assert(localAgentState.is(\.disconnected))
            self = .starting

        case let (.connected(_, connectionData?), .connected(connectionDetails)):
            self = .connected(connectionData, connectionData.connectionDate, connectionDetails)

        case (.connected, .disconnecting):
            self = .disconnecting

        case (.connected, .disconnected(.some)):
            self = .disconnecting

        case (.connected(_, let connectionData?), .disconnected(nil)) where !connectionData.protocolData.tunnelProtocol.requiresLocalCertificateAuthentication:
            // Protocols that don't require app-side cert auth are fully connected once the tunnel is up
            self = .connected(connectionData, connectionData.connectionDate, nil)

        case (.connected(_, let connectionData?), .disconnected(nil)):
            self = .connecting(connectionData)

        case let (.connected(_, connectionData?), .connecting):
            self = .connecting(connectionData)

        case (.connected(_, nil), _):
            // Connection data not yet available
            self = .starting

        case (.disconnecting, .disconnected):
            self = .disconnecting

        case (.disconnecting, .disconnecting):
            self = .disconnecting

        case (.disconnecting, .connected), (.disconnecting, .connecting):
            // Disconnection can be trigged from outside of the app. More info in the README under
            // ExtensionManagerFeature.
            // This transitions the tunnel/network extension into disconnecting -> disconnected states, before we have
            // the opportunity to disconnect the Local Agent. This state is unusual, but not immediately indicative of
            // an error occurring.
            self = .disconnecting

        case let (.disconnected(possibleTunnelError), .connecting),
             let (.disconnected(possibleTunnelError), .connected):
            // Same as the above case, the user may have initiated a disconnection while the app was in the background
            self = .disconnected(possibleTunnelError.map { .tunnel($0) })

        case let (.disconnected(nil), .disconnected(.some(agentError))):
            self = .disconnected(.agent(agentError))

        case let (.disconnected(possibleTunnelError), .disconnecting(_)):
            // While not necessarily an error state, this is unusual because local agent disconnection should be instant.
            // Let's report state as disconnected because local agent connection can just be recreated instantly.
            // This scenario is usually due to the tunnel crashing or being stopped by the system or as a result of
            // user actions outside of the app
            self = .disconnected(possibleTunnelError.map { .tunnel($0) })

        case (.disconnected(nil), .disconnected(nil)):
            let certAuthError: CertificateAuthenticationError? = certAuthState.failed
            let connectionError = certAuthError.map { ConnectionError.certAuth($0) }
            self = .disconnected(connectionError)

        case let (.disconnected(tunnelError?), .disconnected(.some(_))):
            // However unlikely (if even possible due to how actions/events are synchronised by reducers) it might be
            // possible to simultaneously encounter a tunnel and local agent error, the former should take precedence
            self = .disconnected(.tunnel(tunnelError))

        case let (.disconnected(tunnelError?), .disconnected(nil)):
            self = .disconnected(.tunnel(tunnelError))
        }
    }

    init(connectionFeatureState: CoreConnectionFeature.State) {
        self.init(
            tunnelState: connectionFeatureState.tunnel,
            certAuthState: connectionFeatureState.certAuth,
            localAgentState: connectionFeatureState.localAgent
        )
    }
}
