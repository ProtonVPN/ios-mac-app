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
    import Foundation
    import Dependencies
    import Domain
    import IssueReporting
    import CoreConnection
    import class GoLibs.LocalAgentFeatures

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

        func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws(LAConnectionCreationError) {
            disconnectionTask?.cancel()

            if let connectionErrorToThrow {
                throw connectionErrorToThrow
            }

            state = .connecting

            connectionTask = Task { [weak self] in
                try await self?.clock.sleep(for: connectionDuration)
                try Task.checkCancellation()
                log.debug("LocalAgentMock finished connecting")

                self?.state = connectionResult.state
                self?.netShieldType = configuration.features.netshield
                if let error = connectionResult.error {
                    self?.simulate(event: .error(error))
                }
            }
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
                self.netShieldType = features.netshield
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

        func set(features: LocalAgentFeatures) {}
    }

    enum NetShieldStatsBehaviour {
        case random
        case constant(FeatureStatisticsMessage.NetShieldStats)

        var value: FeatureStatisticsMessage.NetShieldStats {
            switch self {
            case .random:
                return FeatureStatisticsMessage.NetShieldStats(
                    malwareBlocked: .random(in: 0...100),
                    adsBlocked: .random(in: 0...100),
                    trackersBlocked: .random(in: 0...100),
                    bytesSaved: .random(in: 0...100)
                )
            case let .constant(value):
                return value
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
