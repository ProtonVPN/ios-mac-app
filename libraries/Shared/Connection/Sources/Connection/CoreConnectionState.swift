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

import CertificateAuthentication
import CoreConnection
import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import ExtensionManager
import LocalAgent

@CasePathable
public enum CoreConnectionState: Equatable, Sendable, CasePathable {
    case unknown
    case disconnected(ConnectionError?)
    case starting
    case connecting(TunnelConnectionResponse?)
    case connected(TunnelConnectionResponse, Date, ConnectionDetailsMessage?)
    case disconnecting

    public init(
        tunnelState: ExtensionFeature.State,
        certAuthState: CertificateAuthenticationFeature.State,
        localAgentState: LocalAgentFeature.State
    ) {
        switch (tunnelState, localAgentState) {
        case (.unknown, _):
            self = .unknown

        case (.preparingConnection, _):
            assert(localAgentState.is(\.disconnected))
            self = .starting

        case (.connecting, _):
            assert(localAgentState.is(\.disconnected))
            self = .starting

        case let (.connected(tunnelConnectionInfo), .connected(connectionDetails)):
            self = .connected(tunnelConnectionInfo, tunnelConnectionInfo.connectionDate, connectionDetails)

        case (.connected, .disconnecting):
            self = .disconnecting

        case (.connected, .disconnected(.some)):
            self = .disconnecting

        case (.connected(let tunnelInfo), .disconnected(nil)):
            self = .connecting(tunnelInfo)

        case let (.connected(tunnelInfo), .connecting):
            self = .connecting(tunnelInfo)

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

        case let (.disconnected(.none), .disconnected(.some(agentError))):
            self = .disconnected(.agent(agentError))

        case let (.disconnected(possibleTunnelError), .disconnecting(_)):
            // While not necessarily an error state, this is unusual because local agent disconnection should be instant.
            // Let's report state as disconnected because local agent connection can just be recreated instantly.
            // This scenario is usually due to the tunnel crashing or being stopped by the system or as a result of
            // user actions outside of the app
            self = .disconnected(possibleTunnelError.map { .tunnel($0) })

        case (.disconnected(.none), .disconnected(.none)):
            let certAuthError: CertificateAuthenticationError? = certAuthState.failed
            let connectionError = certAuthError.map { ConnectionError.certAuth($0) }
            self = .disconnected(connectionError)

        case let (.disconnected(.some(tunnelError)), .disconnected(.some(_))):
            // However unlikely (if even possible due to how actions/events are synchronised by reducers) it might be
            // possible to simultaneously encounter a tunnel and local agent error, the former should take precedence
            self = .disconnected(.tunnel(tunnelError))

        case let (.disconnected(.some(tunnelError)), .disconnected(.none)):
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

enum UnexpectedInternalConnectionState: Error {
    case agentActive
    case agentConnectedWhile
}
