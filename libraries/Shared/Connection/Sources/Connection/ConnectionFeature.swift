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
    @Dependency(\.serverIdentifier) var serverIdentifier

    public init() { }

    public struct State: Equatable, Sendable {
        public var tunnel: ExtensionFeature.State
        public var localAgent: LocalAgentFeature.State
        public var certAuth: CertificateAuthenticationFeature.State

        public init(
            tunnelState: ExtensionFeature.State = .disconnected(nil),
            certAuthState: CertificateAuthenticationFeature.State = .idle,
            localAgentState: LocalAgentFeature.State = .disconnected(nil)
        ) {
            self.tunnel = tunnelState
            self.certAuth = certAuthState
            self.localAgent = localAgentState
        }

        var computedConnectionState: ConnectionState {
            ConnectionState(tunnelState: tunnel, certAuthState: certAuth, localAgentState: localAgent)
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case connect(Server, VPNConnectionFeatures)
        case disconnect(ConnectionError?)
        case tunnel(ExtensionFeature.Action)
        case certAuth(CertificateAuthenticationFeature.Action)
        case localAgent(LocalAgentFeature.Action)
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Scope(state: \.certAuth, action: \.certAuth) { CertificateAuthenticationFeature() }
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

            case .tunnel(.connectionFinished(.success)):
                return .send(.certAuth(.loadAuthenticationData))

            case .localAgent(.connectionFinished(.failure)):
                // TODO: if we encountered a certificate error, try regenerating the certificate
                // For now, let's just disconnect the tunnel.
                // state.localAgent will contain the failure reason so this can be shown in the UI
                return .send(.tunnel(.disconnect))

            case .certAuth(.loadingFinished(.success(let authData))):
                guard case .connected(let logicalInfo) = state.tunnel else {
                    log.error("Finished loading auth data but tunnel is not connected")
                    return .none
                }
                guard let server = serverIdentifier.fullServerInfo(logicalInfo) else {
                    log.error("Detected connection to unknown server, disconnecting", category: .connection)
                    return .send(.disconnect(nil))
                }
                let data = VPNAuthenticationData(clientKey: authData.keys.privateKey, clientCertificate: authData.certificate.certificate)
                return .send(.localAgent(.connect(server.endpoint, data)))

            case .certAuth(.loadingFinished(.failure(let error))):
                log.error("Failed to load authentication data: \(error)")
                return .send(.disconnect(nil))

            case .tunnel:
                return .none

            case .localAgent:
                return .none

            case .certAuth:
                return .none
            }
        }
    }
}

@CasePathable
public enum ConnectionError: Error, Equatable {
    case certAuth(CertificateAuthenticationError)
    case tunnel(TunnelConnectionError)
    case agent(LocalAgentConnectionError)
    case serverMissing
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
