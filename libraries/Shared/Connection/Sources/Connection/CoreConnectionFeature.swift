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

import Clocks
import ComposableArchitecture
import Dependencies

import CoreConnection
import CertificateAuthentication
import ExtensionManager
import LocalAgent
import VPNAppCore

import Domain

@available(iOS 16, *)
public struct CoreConnectionFeature: Reducer, Sendable {
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.serverIdentifier) private var serverIdentifier
    @Dependency(\.tunnelKeychain) private var tunnelConfigKeychain
    @Dependency(\.vpnFeaturesProvider) private var vpnFeaturesProvider

    private static let defaultConnectionTimeout = Duration.seconds(30)

    public init() { }

    public struct State: Equatable, Sendable {
        public internal(set) var tunnel: ExtensionFeature.State
        public internal(set) var localAgent: LocalAgentFeature.State
        public internal(set) var certAuth: CertificateAuthenticationFeature.State

        public init(
            tunnelState: ExtensionFeature.State = .unknown,
            certAuthState: CertificateAuthenticationFeature.State = .idle,
            localAgentState: LocalAgentFeature.State = .disconnected(nil)
        ) {
            self.tunnel = tunnelState
            self.certAuth = certAuthState
            self.localAgent = localAgentState
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case connect(ServerConnectionIntent)
        case disconnect(DisconnectReason)
        case tunnel(ExtensionFeature.Action)
        case certAuth(CertificateAuthenticationFeature.Action)
        case localAgent(LocalAgentFeature.Action)
        case clearErrors
        case startObserving
        case stopObserving
        case handleLogout
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable {
            case stateChanged(CoreConnectionState, CoreConnectionState)
        }
    }

    @CasePathable
    public enum DisconnectReason: Equatable, Sendable {
        case connectionFailure(ConnectionError)
        case userIntent
    }

    private enum CancelID {
        case connectionTimeout
        case observation
    }

    public var body: some Reducer<State, Action> {
        var oldStateCopy: State = .init()
        Reduce { state, action in
            oldStateCopy = state
            return .none
        }
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Scope(state: \.certAuth, action: \.certAuth) { CertificateAuthenticationFeature() }
        Scope(state: \.localAgent, action: \.localAgent) { LocalAgentFeature() }
        Reduce { state, action in
            let effects = reduceCore(state: &state, action: action)
            return reduceWithStateChangeAction(oldState: oldStateCopy, newState: state, effects: effects)
        }
    }

    private func reduceCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startObserving:
            return .merge(
                .send(.tunnel(.startObservingStateChanges)),
                .send(.localAgent(.startObservingEvents))
            )
            .cancellable(id: CancelID.observation, cancelInFlight: true)

        case .stopObserving:
            return .merge(
                .send(.tunnel(.stopObservingStateChanges)),
                .send(.localAgent(.stopAllObservations)),
                .cancel(id: CancelID.connectionTimeout)
            )

        case .connect(let intent):
            assert(CoreConnectionState(connectionFeatureState: state).is(\.disconnected))
            clearErrorsFromPreviousAttempts(state: &state)

            return .run { send in
                await send(.tunnel(.connect(intent)))

                try await clock.sleep(for: Self.defaultConnectionTimeout)
                try Task.checkCancellation()

                await send(.disconnect(.connectionFailure(.timeout)))
            } catch: { error, _ in
                log.info("Timeout task cancellation error: \(error)")
            }.cancellable(id: CancelID.connectionTimeout, cancelInFlight: true)

        case .disconnect:
            return .merge(
                .cancel(id: CancelID.connectionTimeout),
                .send(.localAgent(.disconnect(nil))),
                .send(.tunnel(.disconnect(nil)))
            )

        case .tunnel(.connectionFinished(.success)):
            log.info("Tunnel started: loading authentication data")
            return .send(.certAuth(.loadAuthenticationData))

        case .certAuth(.loadingFinished(.success(let authData))):
            guard case .connected(let tunnelConnectionInfo) = state.tunnel else {
                log.error("Finished loading auth data but tunnel is not connected")
                return .none
            }
            guard let server = serverIdentifier.fullServerInfo(tunnelConnectionInfo.logicalInfo) else {
                log.error("Detected connection to unknown server, disconnecting", category: .connection)
                return .send(.disconnect(.connectionFailure(.serverMissing)))
            }
            let data = VPNAuthenticationData(clientKey: authData.keys.privateKey, clientCertificate: authData.certificate.certificate)
            let features = vpnFeaturesProvider.connectionFeatures()
            return .send(.localAgent(.connect(server.endpoint, data, features)))

        case .certAuth(.loadingFinished(.failure(let error))):
            log.error("Failed to load authentication data: \(error)")
            return .send(.disconnect(.connectionFailure(.certAuth(.unexpected(error)))))

        case .tunnel(.tunnelStatusChanged(.disconnected)):
            if case .disconnected = state.localAgent { return .none }
            // Now that we're fully disconnected, let's cancel the timeout
            return .cancel(id: CancelID.connectionTimeout)

        case .tunnel(.tunnelStartRequestFinished(.failure)):
            // Special case of failure that occurs before the tunnel is started
            return .cancel(id: CancelID.connectionTimeout)

        case .localAgent(.event(.state(.disconnected))):
            guard case .disconnected = state.tunnel else { return .none }
            // Now that we're fully disconnected, let's cancel the timeout
            return .cancel(id: CancelID.connectionTimeout)

        case .localAgent(.event(.state(.connected))):
            return .cancel(id: CancelID.connectionTimeout)

        case .localAgent(.delegate(.errorReceived(let error))):
            log.info("Resolving LocalAgent error with strategy: \(error.resolutionStrategy)", category: .connection)
            switch error.resolutionStrategy {
            case .none:
                return .none

            case .disconnect:
                return .merge(
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.localAgent(.disconnect(.agentError(error)))),
                    .send(.tunnel(.disconnect(nil)))
                )

            case .reconnect(.withNewKeysAndCertificate):
                return .concatenate(
                    .send(.localAgent(.disconnect(nil))),
                    .send(.certAuth(.regenerateKeys)),
                    .send(.certAuth(.loadAuthenticationData))
                )

            case .reconnect(.withNewCertificate):
                return .concatenate(
                    .send(.localAgent(.disconnect(nil))),
                    .send(.certAuth(.purgeCertificate)), // In case it's not just expired
                    .send(.certAuth(.loadAuthenticationData))
                )

            case .reconnect(.withExistingCertificate):
                return .concatenate(
                    .send(.localAgent(.disconnect(nil))),
                    .send(.certAuth(.loadAuthenticationData))
                )
            }

        case .tunnel:
            return .none

        case .localAgent:
            return .none

        case .certAuth:
            return .none

        case .clearErrors:
            if case .failed = state.certAuth{
                state.certAuth = .idle
            }
            if case let .disconnected(error) = state.tunnel, error != nil {
                state.tunnel = .disconnected(nil)
            }
            if case let .disconnected(error) = state.localAgent, error != nil {
                state.localAgent = .disconnected(nil)
            }
            return .none

        case .handleLogout:
            do {
                try tunnelConfigKeychain.clear()
            } catch {
                // An error will be thrown if we haven't made any connections and there is nothing to clear.
                log.debug("Error clearing VPN keychain: \(error)")
            }
            return .merge(
                .send(.tunnel(.removeManagers)),
                .send(.certAuth(.clearEverything))
            )
        case .delegate:
            return .none
        }
    }

    private func clearErrorsFromPreviousAttempts(state: inout State) {
        if case .disconnected(let tunnelError) = state.tunnel, let tunnelError {
            log.info("Resetting tunnel connection error from previous connection attempt: \(tunnelError)")
            state.tunnel = .disconnected(nil)
        }
        if case .failed(let certAuthError) = state.certAuth {
            log.info("Resetting cert auth error from previous connection attempt: \(certAuthError)")
            state.certAuth = .idle
        }
        if case .disconnected(let agentError) = state.localAgent, let agentError {
            log.info("Resetting local agent connection error from previous connection attempt: \(agentError)")
            state.localAgent = .disconnected(nil)
        }
    }

    private func reduceWithStateChangeAction(
        oldState: CoreConnectionFeature.State,
        newState: CoreConnectionFeature.State,
        effects: Effect<Action>
    ) -> Effect<Action> {
        let oldValue = CoreConnectionState(connectionFeatureState: oldState)
        let newValue = CoreConnectionState(connectionFeatureState: newState)
        if oldValue == newValue {
            return effects
        }
        return .concatenate(.send(.delegate(.stateChanged(oldValue, newValue))), effects)
    }
}
