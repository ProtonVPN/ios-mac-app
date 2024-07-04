//
//  Created on 03/06/2024.
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

import ComposableArchitecture

import struct Domain.ServerEndpoint
import ConnectionFoundations

public struct LocalAgentFeature: Reducer, Sendable {
    @Dependency(\.localAgent) var localAgent
    @Dependency(\.localAgentConfiguration) var configuration

    public init() { }

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case disconnected(LocalAgentConnectionError?)
        case connecting
        case connected(ConnectionDetailsMessage?)
    }

    @CasePathable
    public enum Action: Sendable {
        case startObservingEvents
        case stopObservingEvents
        case event(LocalAgentEvent)
        case connect(ServerEndpoint, VPNAuthenticationData)
        case disconnect
    }

    private enum CancelID { case observation }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObservingEvents:
                return .run { send in
                    for await event in self.localAgent.eventStream {
                        await send(.event(event))
                    }
                }
                .cancellable(id: CancelID.observation)

            case .stopObservingEvents:
                return .cancel(id: CancelID.observation)

            case .event(.state(.disconnected)):
                state = .disconnected(nil)
                return .none

            case .event(.state(.connecting)):
                state = .connecting
                return .none

            case .event(.state(.serverUnreachable)):
                // LA can briefly enter this state when its connection times out before retrying

                // Set state as connecting just in case this happens after connection
                // This should update the UI to reflect that we are reconnecting.
                state = .connecting
                return .none

            case .event(.state(.connected)):
                let existingConnectionDetails = state.connected ?? nil
                state = .connected(existingConnectionDetails)
                return .none

            case .event(.state(.connectionError)):
                // Possible if we attempt to connect to a different server than the one the tunnel is established with
                // `tls: failed to verify certificate: x509: certificate is valid for node-abc.net, not node-xyz.net`

                // Set state as connecting just in case this happens after connection
                // This should update the UI to reflect that we are (re)connecting.
                state = .connecting
                return .none

            case .event(.state(.softJailed)),
                .event(.state(.hardJailed)),
                .event(.state(.clientCertificateError)):

                return .none

            case .event(.state(.invalid)):
                log.assertionFailure("LocalAgent entered invalid/unknown state")
                return .none

            case .event(.connectionDetails(let connectionDetails)):
                state = .connected(connectionDetails)
                return .none

            case .event:
                return .none

            case .connect(let server, let authenticationData):
                state = .connecting

                let connectionConfiguration = ConnectionConfiguration(
                    hostname: server.domain,
                    netshield: .level1,
                    vpnAccelerator: true,
                    bouncing: server.label,
                    natType: .moderateNAT,
                    safeMode: false
                )

                do {
                    // Not a blocking call. Starts the LA connection process which, if unsuccessful, will continue to
                    // retry with increasing backoff delays.
                    try localAgent.connect(configuration: connectionConfiguration, data: authenticationData)
                } catch {
                    state = .disconnected(.failedToEstablishConnection(error))
                }
                return .none

            case .disconnect:
                localAgent.disconnect()
                state = .disconnected(nil)
                return .none
            }
        }
    }
}

@CasePathable
public enum LocalAgentConnectionError: Error, Equatable {
    case failedToEstablishConnection(Error?)

    /// Equatable conformance is only required because feature state must be equatable. We could probably always return
    /// `true`, but for now let's just ignore associated values
    public static func == (lhs: LocalAgentConnectionError, rhs: LocalAgentConnectionError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToEstablishConnection, .failedToEstablishConnection):
            return true
        }
    }
}
