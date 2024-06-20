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

import Foundation
import XCTestDynamicOverlay
import ConnectionFoundations
@testable import LocalAgent

final class LocalAgentMock: LocalAgent {

    private var eventHandler: ((LocalAgentEvent) -> Void)?
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

    var eventStream: AsyncStream<LocalAgentEvent> {
        AsyncStream { continuation in
            eventHandler = { event in
                continuation.yield(event)
            }
            continuation.onTermination = { @Sendable _ in
                self.eventHandler = nil
            }
        }
    }

    var connectionErrorToThrow: Error?

    init(
        state: LocalAgentState,
        connectionErrorToThrow: Error? = nil
    ) {
        self.state = state
        self.connectionErrorToThrow = connectionErrorToThrow
    }

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws {
        if let connectionErrorToThrow {
            throw connectionErrorToThrow
        }
    }
    
    func disconnect() {
        state = .disconnected
    }
}
