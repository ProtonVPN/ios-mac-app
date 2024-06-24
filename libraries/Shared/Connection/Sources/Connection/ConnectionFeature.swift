//
//  Created on 28/05/2024.
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
import enum NetworkExtension.NEVPNStatus

import ComposableArchitecture
import Dependencies

import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import ConnectionFoundations
import CertificateAuthentication
import ExtensionManager
import LocalAgent

public struct ConnectionFeature: Reducer, Sendable {
    @Dependency(\.certificateAuthentication) var certificateAuthentication
    @Dependency(\.serverIdentifier) var serverIdentifier

    public init() { }

    public struct State: Equatable, Sendable {
        public var tunnel: ExtensionFeature.State
        public var localAgent: LocalAgentFeature.State

        public init(
            tunnelState: ExtensionFeature.State = .disconnected(nil),
            localAgentState: LocalAgentFeature.State = .disconnected(nil)
        ) {
            self.tunnel = tunnelState
            self.localAgent = localAgentState
        }

        var computedConnectionState: ConnectionState {
            ConnectionState(tunnelState: tunnel, localAgentState: localAgent)
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case connect(Server, VPNConnectionFeatures)
        case disconnect(ConnectionError?)
        case tunnel(ExtensionFeature.Action)
        case localAgent(LocalAgentFeature.Action)
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Scope(state: \.localAgent, action: \.localAgent) { LocalAgentFeature() }
        Reduce { state, action in
            switch action {
            case .connect(let server, let features):
                return .send(.tunnel(.connect(server, features)))

            case .disconnect:
                return .merge(
                    .send(.localAgent(.disconnect)),
                    .send(.tunnel(.disconnect))
                )

            case .tunnel(.connectionFinished(.success(let logicalServerInfo))):
                // certificateAuthentication.
                guard let server = serverIdentifier.fullServerInfo(logicalServerInfo) else {
                    log.error("Detected connection to unknown server, disconnecting", category: .connection, metadata: ["logicalServerInfo": "\(logicalServerInfo)"])
                    return .send(.disconnect(.tunnel(.unknownServer)))
                }
                return .run { send in
                    // TODO: Cert-Auth - ensure correct features, handle failures
                    let authData = try await certificateAuthentication.loadAuthenticationData(nil) // features: nil for now
                    await send(.localAgent(.connect(server.endpoint, authData)))
                }

            case .localAgent(.connectionFinished(.failure)):
                // TODO: Certificate Authentication: check if error is retriable, try connecting again
                // For now, let's just disconnect the tunnel.
                // state.localAgent will contain the failure reason so this can be shown in the UI
                return .send(.tunnel(.disconnect))

            case .tunnel:
                return .none
            case .localAgent:
                return .none
            }
        }
    }
}

@CasePathable
public enum ConnectionError: Error, Equatable {
    case tunnel(TunnelConnectionError)
    case agent(LocalAgentConnectionError)
    case serverMissing

    public var description: String {
        switch self {

        case .tunnel(_):
            return ""
        case .agent(_):
            return ""
        case .serverMissing:
            return "Couldn't find specified server"
        }
    }
}

// For now, let's override the dump descriptions with minimal info so `_printChanges` reducer is easier to read
extension Domain.Server: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "Server(\(logical.name))"
    }
}
extension Domain.VPNConnectionFeatures: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "VPNConnectionFeatures"
    }
}
