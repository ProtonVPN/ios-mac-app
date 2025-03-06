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

import CoreConnection
import class GoLibs.LocalAgentFeatures

import Domain
import Strings
import Ergonomics

@available(iOS 16, *)
public struct LocalAgentFeature: Reducer, Sendable {
    static let netShieldTimerInterval: Duration = .seconds(60)
    static let netShieldTimerTolerance: Duration = .seconds(5)

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
        case startNetShieldStatsObservation
        case stopAllObservations
        case setFeatures(Set<ConnectionFeatureChange.AgentFeature>)
        case event(LocalAgentEvent)
        case connect(ServerEndpoint, VPNAuthenticationData, VPNConnectionFeatures)
        case disconnect(LocalAgentConnectionError?)
        case delegate(DelegateAction)

        @CasePathable
        public enum DelegateAction: Sendable {
            case certificateRefreshRequired
            case keyRegenerationRequired
            case errorReceived(LocalAgentError)
            case connectionFailed(Error)
        }
    }

    private enum CancelIDs {
        case eventObservation
        case netshieldStatsObservation
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObservingEvents:
                // TODO: (nit) Use new .listen TCA helper!
                return .run { send in
                    for await event in self.localAgent.createEventStream() {
                        await send(.event(event))
                    }
                }
                .cancellable(id: CancelIDs.eventObservation)

            case .stopAllObservations:
                return .merge(
                    .cancel(id: CancelIDs.eventObservation),
                    .cancel(id: CancelIDs.netshieldStatsObservation)
                )

            case .setFeatures(let featureSet):
                guard case .connected = state else {
                    log.error("Feature changes will not be applied since we are not in connected state", category: .connection, metadata: ["state": "\(state)"])
                    return .none
                }
                guard let features = LocalAgentFeatures.from(featureSet: featureSet) else {
                    log.error("Failed to construct LocalAgentFeatures", category: .connection, metadata: ["features": "\(featureSet)"])
                    return .none
                }
                localAgent.set(features: features)
                return .none

            case .connect(let server, let authenticationData, let features):
                let connectionConfiguration = ConnectionConfiguration(server: server, features: features)
                do {
                    // Not a blocking call. Creates the connection to the Local Agent server
                    // If successful, will remain in the disconnected state until a reply is received,
                    // retrying with increasing backoff delays.
                    // If unsuccessful (e.g. because of mismatched private/public keys), an error is thrown.
                    // This error is in the "go" domain, rather than one of our well defined LocalAgentErrors
                    try localAgent.connect(configuration: connectionConfiguration, data: authenticationData)
                    return .send(.startNetShieldStatsObservation)
                } catch {
                    log.error("Failed to create connection to Local Agent server", category: .localAgent, metadata: ["error": "\(error)"])
                    state = .disconnected(.failedToEstablishConnection(error))
                    return .send(.delegate(.connectionFailed(error)))
                }

            case .disconnect(let error):
                guard state.shouldTransitionToDisconnecting else { return .none }
                state = .disconnecting(error)
                localAgent.disconnect()
                return .none

            case .event(.state(.disconnected)):
                // Persist potential errors causing the disconnection, saved in the previous state
                let existingError: LocalAgentConnectionError? = state.disconnected ?? state.disconnecting ?? nil
                state = .disconnected(existingError)
                return .cancel(id: CancelIDs.netshieldStatsObservation)

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

            case .event(.state(.softJailed)), .event(.state(.hardJailed)), .event(.state(.clientCertificateError)):
                return .send(.delegate(.certificateRefreshRequired))

            case .event(.state(.invalid)):
                log.assertionFailure("LocalAgent entered invalid/unknown state")
                return .none

            case .event(.connectionDetails(let connectionDetails)):
                state = .connected(connectionDetails)
                return .none

            case .event(.error(let error)):
                return .send(.delegate(.errorReceived(error)))

            case .event(.features(let features)):
                log.info("Features received: \(features)")
                return .none

            case .event(.stats(let stats)):
                log.debug("Feature statistics received: \(stats)")
                return .none

            case .delegate:
                return .none // Delegate actions to be handled by parent

            case .startNetShieldStatsObservation:
                return .timer(interval: Self.netShieldTimerInterval, tolerance: Self.netShieldTimerTolerance) { _ in
                    localAgent.retrieveNetShieldStats()
                }
                .cancellable(id: CancelIDs.netshieldStatsObservation)
            }
        }
    }
}

@CasePathable
public enum LocalAgentConnectionError: Error, Equatable {
    /// Thrown during the initial connection attempt - wasn't able to establish a connection with the LocalAgent server.
    case failedToEstablishConnection(Error)
    /// Raised by the agent after connecting. Usually sent by the server to us about something bad about our connection.
    case agentError(LocalAgentError)
    /// A certificate error occurred when attempting to connect to the LocalAgent server.
    case serverCertificateError

    /// Equatable conformance is only required because feature state must be equatable. We could probably always return
    /// `true`, but for now let's just ignore associated values
    public static func == (lhs: LocalAgentConnectionError, rhs: LocalAgentConnectionError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToEstablishConnection, .failedToEstablishConnection):
            return true

        case (.agentError, .agentError):
            return true

        case (.serverCertificateError, .serverCertificateError):
            return true

        default:
            return false
        }
    }
}

extension LocalAgentConnectionError: ProtonVPNError {
    public static let errorDomain = "LocalAgentConnectionErrorDomain"

    public var errorDescription: String? {
        switch self {
        case .failedToEstablishConnection(let connectionError):
            return Localizable.connectionErrorLocalAgentFailedEstablishingConnection(String(describing: connectionError))
        case .agentError(let agentError):
            return Localizable.connectionErrorLocalAgentRemoteError(String(describing: agentError))
        case .serverCertificateError:
            return Localizable.connectionErrorLocalAgentServerCertificate
        }
    }

    public var charCode: FourCharCode {
        switch self {
        case .failedToEstablishConnection:
            return "FCNT"
        case .agentError:
            return "AGNT"
        case .serverCertificateError:
            return "SCRT"
        }
    }

    public var errorUserInfo: [String : Any] {
        var result: [String: Any] = [
            NSLocalizedDescriptionKey: errorDescription ?? "unknown error",
        ]

        switch self {
        case .failedToEstablishConnection(let connectionError):
            result[NSUnderlyingErrorKey] = connectionError
        case .agentError(let agentError):
            result[NSUnderlyingErrorKey] = agentError
        default:
            break
        }

        return result
    }
}

package enum LocalAgentErrorResolutionStrategy {
    case none // do nothing, error might resolve itself or doesn't warrant a response
    case disconnect
    case reconnect(ReconnectionStrategy)

    package enum ReconnectionStrategy {
        case withNewKeysAndCertificate
        case withNewCertificate
        case withExistingCertificate
    }
}

extension LocalAgentError {

    package var resolutionStrategy: LocalAgentErrorResolutionStrategy {
        switch self {
        case .systemError:
            // Most likely we just failed to apply a feature/setting
            return .none

        case .restrictedServer:
            // Restricted server, unable to verify the certificate yet: Wait or try another server
            return .none

        case .certificateExpired, .certificateNotProvided:
            // If the certificate is expired or missing, we will detect this and refresh it, there is no need to
            // explicitly regenerate it
            return .reconnect(.withExistingCertificate)

        case .badCertificateSignature, .certificateRevoked, .keyUsedMultipleTimes, .serverSessionDoesNotMatch:
            return .reconnect(.withNewKeysAndCertificate)

        case .maxSessionsUnknown,
                .maxSessionsFree,
                .maxSessionsBasic,
                .maxSessionsPlus,
                .maxSessionsVisionary,
                .maxSessionsPro,
                .serverError,
                .policyViolationLowPlan,
                .policyViolationDelinquent,
                .userTorrentNotAllowed,
                .userBadBehavior,
                .guestSession:
            // The error shown on disconnection is customised through its implementation of AlertConvertibleError
            return .disconnect

        case .unknown:
            return .none
        }
    }
}

private extension LocalAgentFeature.State {
    var shouldTransitionToDisconnecting: Bool {
        switch self {
        case .connecting, .connected:
            return true
        case .disconnecting, .disconnected:
            return false
        }
    }
}

public extension Effect {
    static func timer(
        interval: Duration,
        tolerance: Duration? = nil,
        operation: @escaping @Sendable @MainActor (_ send: Send<Action>) async throws -> Void,
        catch handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
    ) -> Self {
        self.run(
            operation: { send in
                @Dependency(\.continuousClock) var clock
                for await _ in clock.timer(interval: interval, tolerance: tolerance) {
                    try await operation(send)
                }
            },
            catch: handler
        )
    }
}
