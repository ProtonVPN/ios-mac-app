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

import CoreConnection
import CertificateAuthentication
import ExtensionManager
import LocalAgent
import struct Domain.Server
import struct Domain.VPNConnectionFeatures

@available(iOS 16, *)
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

        case (.connected(let tunnelConnectionInfo), .connected(let connectionDetails)):
//            @Dependency(\.serverIdentifier) var serverIdentifier
//            guard let server = serverIdentifier.fullServerInfo(tunnelConnectionInfo.logicalInfo) else {
//                assertionFailure("Unknown server")
//                self = .disconnected(.serverMissing)
//                return
//            }
            self = .connected(tunnelConnectionInfo, tunnelConnectionInfo.connectionDate, connectionDetails)

        case (.connected, .disconnecting):
            self = .disconnecting

        case (.connected, .disconnected(.some)):
            self = .disconnecting

        case (.connected(let tunnelInfo), _):
            self = .connecting(tunnelInfo) //(nil)

        case (.preparingConnection(let logicalServerInfo), _):
//            @Dependency(\.serverIdentifier) var serverIdentifier
//            let server = serverIdentifier.fullServerInfo(logicalServerInfo)
            self = .starting // (server)

        case (.connecting(let logicalServerInfo), _):
//            let server = logicalServerInfo.flatMap {
//                @Dependency(\.serverIdentifier) var serverIdentifier
//                return serverIdentifier.fullServerInfo($0)
//            }
            self = .starting // (server)

        case (.disconnecting, _):
            self = .disconnecting

        case (.disconnected(.none), .disconnected(.some(let agentError))):
            self = .disconnected(.agent(agentError))

        case (.disconnected(.some(let tunnelError)), _):
            self = .disconnected(.tunnel(tunnelError))

        case (.disconnected(.none), .connecting):
            assertionFailure("State should not be possible")
            self = .disconnected(nil)

        case (.disconnected(.none), .connected):
            assertionFailure("State should not be possible")
            self = .disconnected(nil)

        case (.disconnected(.none), .disconnecting(_)):
            self = .disconnecting
        case (.disconnected(.none), .disconnected(.none)):
            let certAuthError: CertificateAuthenticationError? = certAuthState.failed
            let connectionError = certAuthError.map { ConnectionError.certAuth($0) }
            self = .disconnected(connectionError)
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
