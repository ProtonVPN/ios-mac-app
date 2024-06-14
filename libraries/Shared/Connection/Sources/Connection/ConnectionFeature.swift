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

        public init(tunnelState: ExtensionFeature.State, localAgentState: LocalAgentFeature.State) {
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
        case disconnect
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
                return .concatenate(
                    .send(.localAgent(.disconnect)),
                    .send(.tunnel(.disconnect))
                )

            case .tunnel(.connectionFinished(.success(let logicalServerInfo))):
                // certificateAuthentication.
                guard let server = serverIdentifier.fullServerInfo(logicalServerInfo) else {
                    // TODO: log, disconnect, or handle this in an otherwise sensible way
                    fatalError("We don't have information about this server in our DB")
                }
                return .run { send in
                    // TODO: Cert-Auth - ensure correct features, handle failures
                    let authData = try await certificateAuthentication.loadAuthenticationData()
                    await send(.localAgent(.connect(server.endpoint, authData)))
                }

            case .tunnel(.tunnelStartRequestFinished(.success(let session))):
                print(session)
                return .none
                
            case .tunnel:
                return .none

            case .localAgent:
                return .none

            case .stateChanged:
                return .none
            }
        }
    }
}

@CasePathable
public enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(country: String, ip: String)
    case disconnecting

    public init(
        tunnelState: ExtensionFeature.State,
        localAgentState: LocalAgentFeature.State
    ) {
        switch (tunnelState, localAgentState) {
        case (.connected, .connected):
            self = .connected(country: "CH", ip: "1.2.3.4")

        case (.connected, _), (.connecting, _):
            self = .connecting

        case (.disconnecting, _):
            self = .disconnecting

        case (.disconnected, _):
            self = .disconnected
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
