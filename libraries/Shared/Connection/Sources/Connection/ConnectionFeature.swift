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
        var tunnel: ExtensionFeature.State
        var localAgent: LocalAgentFeature.State

        public init(
            tunnelState: ExtensionFeature.State = .disconnected(nil),
            localAgentState: LocalAgentFeature.State = .disconnected(nil)
        ) {
            self.tunnel = tunnelState
            self.localAgent = localAgentState
        }

        var connectionState: ConnectionState {
            return ConnectionState(tunnelState: tunnel, localAgentState: localAgent)
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case connect(Server, VPNConnectionFeatures)
        case disconnect(ConnectionError?)
        case tunnel(ExtensionFeature.Action)
        case localAgent(LocalAgentFeature.Action)
        case stateChanged(ConnectionState)
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
                    let authData = try await certificateAuthentication.loadAuthenticationData()
                    await send(.localAgent(.connect(server.endpoint, authData)))
                }

            case .localAgent(.connectionFinished(.failure)):
                // TODO: Certificate Authentication: check if error is retriable, try connecting again
                // For now, let's just disconnect the tunnel.
                // state.localAgent will contain the failure reason so this can be shown in the UI
                return .send(.tunnel(.disconnect))

            case .tunnel:
                return .send(.stateChanged(state.connectionState))

            case .localAgent:
                return .send(.stateChanged(state.connectionState))

            case .stateChanged:
                return .none
            }
        }
    }
}

@CasePathable
public enum ConnectionError: Error, Equatable {
    case tunnel(TunnelConnectionError)
    case agent(LocalAgentConnectionError)
}

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
        switch (tunnelState, localAgentState) {
        case (.disconnected(let tunnelError), .disconnected(let agentError)):
            // Once both components are disconnected, prioritise returning tunnel errors over local agent errors
            let potentialError: ConnectionError? = tunnelError.map { .tunnel($0) } ?? agentError.map { .agent($0) }
            self = .disconnected(potentialError)

        case (.disconnected(let tunnelError), _):
            self = .disconnected(tunnelError.map { .tunnel($0) })

        case (_, .disconnected(let agentError)):
            self = .disconnected(agentError.map { .agent($0) })

        case (.connected(let logicalServerInfo), .connected):
            @Dependency(\.serverIdentifier) var serverIdentifier
            guard let server = serverIdentifier.fullServerInfo(logicalServerInfo) else {
                fatalError("Unknown server")
            }
            self = .connected(server)

        case (.connected, _), (.connecting, _):
            self = .connecting

        case (.disconnecting, _):
            self = .disconnecting
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
