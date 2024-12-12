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
import XCTestDynamicOverlay
import CoreConnection

@available(iOS 16, *)
final class LocalAgentMock: LocalAgent {
    @Dependency(\.continuousClock) var clock

    private(set) var netShieldType: NetShieldType = .off

    private var state: LocalAgentState {
        didSet {
            streamTuple?.1.yield(.state(state))
        }
    }

    var connectionTask: Task<Void, Error>?
    var connectionDuration: Duration = .milliseconds(500)
    var connectionErrorToThrow: Error?
    var disconnectionTask: Task<Void, Error>?
    var disconnectionDuration: Duration = .milliseconds(250)

    var streamTuple: (stream: AsyncStream<LocalAgentEvent>, continuation: AsyncStream<LocalAgentEvent>.Continuation)?

    init(
        state: LocalAgentState,
        connectionErrorToThrow: Error? = nil
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

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws {
        disconnectionTask?.cancel()

        if let connectionErrorToThrow {
            throw connectionErrorToThrow
        }

        state = .connecting

        connectionTask = Task {
            try await clock.sleep(for: connectionDuration)
            self.state = .connected
            self.netShieldType = configuration.features.netshield
        }
    }

    func disconnect() {
        disconnectionTask = Task {
            try await clock.sleep(for: disconnectionDuration)
            self.state = .disconnected
        }
    }

    func retrieveNetShieldStats() {
        let netshieldStats = FeatureStatisticsMessage.NetShieldStats(
            malwareBlocked: .random(in: 0...100),
            adsBlocked: .random(in: 0...100),
            trackersBlocked: .random(in: 0...100),
            bytesSaved: .random(in: 0...100)
        )
        let message = FeatureStatisticsMessage(netShield: netshieldStats)
        streamTuple?.continuation.yield(.stats(message))
    }
}
#endif
