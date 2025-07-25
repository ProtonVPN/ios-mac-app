//
//  Created on 13/06/2024.
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

#if targetEnvironment(simulator)
    import CoreConnection
    import Dependencies
    import Domain
    import Foundation
    import class GoLibs.LocalAgentFeatures
    import IssueReporting

    @available(iOS 16, *)
    final class LocalAgentMock: LocalAgent {
        @Dependency(\.continuousClock) var clock

        private(set) var netShieldType: NetShieldType = .off
        var netShieldStatsBehaviour: NetShieldStatsBehaviour = .random

        private var state: LocalAgentState {
            didSet {
                streamTuple?.continuation.yield(.state(state))
            }
        }

        var connectionTask: Task<Void, Error>?
        var connectionDuration: Duration = .milliseconds(500)
        var connectionErrorToThrow: LAConnectionCreationError?
        var connectionResult: ConnectionResult = .success
        var disconnectionTask: Task<Void, Error>?
        var disconnectionDuration: Duration = .milliseconds(250)

        // For mocking delayed connections initiated when there was no connectivity
        var configurationToConnectWithAfterConnectivityRestored: ConnectionConfiguration?

        // Invoked when connectivity is set externally
        var onConnectivityUpdate: ((Bool) -> Void)?

        var didRequestStats: (() -> Void)?

        var streamTuple: (stream: AsyncStream<LocalAgentEvent>, continuation: AsyncStream<LocalAgentEvent>.Continuation)?

        init(
            state: LocalAgentState,
            connectionErrorToThrow: LAConnectionCreationError? = nil
        ) {
            self.streamTuple = AsyncStream<LocalAgentEvent>.makeStream()

            self.state = state
            self.connectionErrorToThrow = connectionErrorToThrow
        }

        func createEventStream() -> AsyncStream<LocalAgentEvent> {
            let tuple = AsyncStream<LocalAgentEvent>.makeStream()
            streamTuple = tuple
            return tuple.stream
        }

        func connect(configuration: ConnectionConfiguration, data _: VPNAuthenticationData) throws(LAConnectionCreationError) {
            disconnectionTask?.cancel()

            if let connectionErrorToThrow {
                throw connectionErrorToThrow
            }

            state = .connecting

            if !configuration.connectivity {
                log.info("Connectivity set to false, waiting for network")
                configurationToConnectWithAfterConnectivityRestored = configuration
                return
            }

            connectionTask = startConnectionTask(
                duration: connectionDuration,
                configuration: configuration,
                result: connectionResult
            )
        }

        /// Simulate receiving an `event` - yielding the corresponding value in the `AsyncStream`
        /// and handling explicitly if necessary
        func simulate(event: LocalAgentEvent) {
            // Special handling of events
            switch event {
            case let .state(state):
                self.state = state
            // assigning to state already yields the value - no need to yield here

            case let .features(features):
                netShieldType = features.netshield
                streamTuple?.continuation.yield(event)

            default:
                streamTuple?.continuation.yield(event)
            }
        }

        func disconnect() {
            disconnectionTask = Task {
                try await clock.sleep(for: disconnectionDuration)
                try Task.checkCancellation()
                log.debug("LocalAgentMock finished disconnecting")
                self.state = .disconnected
            }
        }

        func retrieveNetShieldStats() {
            didRequestStats?()
            let message = FeatureStatisticsMessage(netShield: netShieldStatsBehaviour.value)
            streamTuple?.continuation.yield(.stats(message))
        }

        func set(features _: LocalAgentFeatures) {}

        func setConnectivity(_ hasConnectivity: Bool) {
            onConnectivityUpdate?(hasConnectivity)
            guard hasConnectivity else { return }
            if let configurationToConnectWithAfterConnectivityRestored {
                self.configurationToConnectWithAfterConnectivityRestored = nil
                connectionTask = startConnectionTask(
                    duration: connectionDuration,
                    configuration: configurationToConnectWithAfterConnectivityRestored,
                    result: connectionResult
                )
            }
        }

        private func startConnectionTask(
            duration _: Duration,
            configuration: ConnectionConfiguration,
            result: ConnectionResult
        ) -> Task<Void, Error> {
            Task {
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: connectionDuration)
                try Task.checkCancellation()
                log.debug("LocalAgentMock finished connecting")

                state = result.state
                netShieldType = configuration.features.netshield
                if let error = result.error {
                    simulate(event: .error(error))
                }
            }
        }
    }

    enum NetShieldStatsBehaviour {
        case random
        case constant(FeatureStatisticsMessage.NetShieldStats)

        var value: FeatureStatisticsMessage.NetShieldStats {
            switch self {
            case .random:
                FeatureStatisticsMessage.NetShieldStats(
                    malwareBlocked: .random(in: 0 ... 100),
                    adsBlocked: .random(in: 0 ... 100),
                    trackersBlocked: .random(in: 0 ... 100),
                    bytesSaved: .random(in: 0 ... 100)
                )
            case let .constant(value):
                value
            }
        }
    }

    /// Use this to model what state `LocalAgentMock` should enter once it finishes connecting to the server
    struct ConnectionResult {
        let state: LocalAgentState
        let error: LocalAgentError?

        static let success = ConnectionResult(state: .connected, error: nil)

        init(state: LocalAgentState, error: LocalAgentError?) {
            self.state = state
            self.error = error
        }
    }
#endif
