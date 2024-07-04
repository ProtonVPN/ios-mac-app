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
        case connecting
        case connected(ConnectionDetailsMessage?)
        case disconnecting(LocalAgentConnectionError?)
        case disconnected(LocalAgentConnectionError?)
    }

    @CasePathable
    public enum Action: Sendable {
        case startObservingEvents
        case stopObservingEvents
        case event(LocalAgentEvent)
        case connect(ServerEndpoint, VPNAuthenticationData)
        case disconnect(LocalAgentConnectionError?)

        case certificateRefreshRequired
        case keyRegenerationRequired
        case errorReceived(LocalAgentError)
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

            case .connect(let server, let authenticationData):
                state = .connecting

                let connectionConfiguration = ConnectionConfiguration(
                    hostname: server.domain, // "node-kr-03.protonvpn.net",
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

            case .disconnect(let error):
                state = .disconnecting(error)
                localAgent.disconnect()
                return .none

            case .event(.state(.disconnected)):
                // Persist potential errors causing the disconnection, saved in the previous state
                let existingError: LocalAgentConnectionError? = state.disconnected ?? state.disconnecting ?? nil
                state = .disconnected(existingError)
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
                // We enter this state when attempting to connect to a different server than the one the tunnel is
                // established with:
                // `tls: failed to verify certificate: x509: certificate is valid for node-abc.net, not node-xyz.net`

                // Since we time out unsuccessful connections after a set period, and briefly after this state
                // transition, LA attempts to reconnect, let's not immediately disconnect but instead set the state to
                // connecting such that if this happens after connection, this change is reflected in the UI.
                state = .connecting
                return .none

            case .event(.state(.serverCertificateError)):
                // It's unclear when we enter this state, intuitively this should happen in the scenario described
                // above: `case .event(.state(.connectionError)):`, but it does not.
                // If we do enter this state, let's disconnect, since we are most likely connecting to the wrong server
                return .send(.disconnect(.serverCertificateError))

            case .event(.state(.softJailed)),
                .event(.state(.hardJailed)),
                .event(.state(.clientCertificateError)):
                return .send(.certificateRefreshRequired)

            case .event(.state(.invalid)):
                log.assertionFailure("LocalAgent entered invalid/unknown state")
                return .none

            case .event(.connectionDetails(let connectionDetails)):
                state = .connected(connectionDetails)
                return .none

            case .event(.error(let error)):
                return .send(.errorReceived(error))

            case .event(.features(let features)):
                log.info("Features received: \(features)")
                return .none

            case .event(.stats(let stats)):
                log.info("Feature statistics received: \(stats)")
                return .none

            case .certificateRefreshRequired,
                    .keyRegenerationRequired,
                    .errorReceived:

                // Delegate actions to be handled by parent
                return .none
            }
        }
    }
}

@CasePathable
public enum LocalAgentConnectionError: Error, Equatable {
    case failedToEstablishConnection(Error) // Thrown during the initial connection attempt
    case agentError(LocalAgentError) // Raised by the agent after connecting
    case serverCertificateError

    /// Equatable conformance is only required because feature state must be equatable. We could probably always return
    /// `true`, but for now let's just ignore associated values
    public static func == (lhs: LocalAgentConnectionError, rhs: LocalAgentConnectionError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToEstablishConnection, .failedToEstablishConnection):
            return true

        case (.agentError, .agentError):
            return true

        default:
            return false
        }
    }
}


enum LocalAgentErrorResolutionStrategy {
    case none // do nothing, error might resolve itself or doesn't warrant a response
    case disconnect
    case reconnect(ReconnectionStrategy)

    enum ReconnectionStrategy {
        case withNewKeysAndCertificate
        case withNewCertificate
        case withExistingCertificate
    }
}

extension LocalAgentError {

    var resolutionStrategy: LocalAgentErrorResolutionStrategy {
        switch self {
        case .systemError:
            // Most likely we just failed to apply a feature/setting
            return .none

        case .restrictedServer:
            // Restricted server, unable to verify the certificate yet: Wait or try another server
            return .none

        case .certificateExpired, .certificateNotProvided:
            return .reconnect(.withNewCertificate)

        case .badCertificateSignature, .certificateRevoked, .keyUsedMultipleTimes, .serverSessionDoesNotMatch:
            return .reconnect(.withNewKeysAndCertificate)

        default:
            return .disconnect
        }
    }
}
