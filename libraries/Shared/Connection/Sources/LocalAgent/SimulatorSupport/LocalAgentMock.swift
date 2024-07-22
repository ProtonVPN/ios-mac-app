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
import XCTestDynamicOverlay
import ConnectionFoundations

@available(iOS 16, *)
final class LocalAgentMock: LocalAgent {
    @Dependency(\.continuousClock) var clock

    var eventHandler: ((LocalAgentEvent) -> Void)?

    var state: LocalAgentState {
        didSet {
            guard let eventHandler else {
                // If this failure is triggered in tests, this mock was used before a reducer subscribed to receive
                // events through `eventStream`.
                XCTFail("Event was emitted but handler is nil")
                return
            }
            eventHandler(.state(state))
        }
    }

    func createEventStream() -> AsyncStream<LocalAgentEvent> {
        AsyncStream { continuation in
            eventHandler = { event in
                continuation.yield(event)
            }
            continuation.onTermination = { @Sendable _ in
                self.eventHandler = nil
            }
        }
    }

    var connectionTask: Task<Void, Error>?
    var connectionDuration: Duration = .milliseconds(500)
    var connectionErrorToThrow: Error?
    var disconnectionTask: Task<Void, Error>?
    var disconnectionDuration: Duration = .milliseconds(250)

    init(
        state: LocalAgentState,
        connectionErrorToThrow: Error? = nil
    ) {
        self.state = state
        self.connectionErrorToThrow = connectionErrorToThrow
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
        }
    }

    func disconnect() {
        disconnectionTask = Task {
            try await clock.sleep(for: disconnectionDuration)
            self.state = .disconnected
        }
    }
}

#endif
