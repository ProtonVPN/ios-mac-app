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
import XCTestDynamicOverlay
import Dependencies
import ConnectionFoundations

final class LocalAgentImplementation: LocalAgent {
    @Dependency(\.localAgentConnectionFactory) var connectionFactory

    private var connection: LocalAgentConnection?
    private let client: LocalAgentClient
    private var previousState: LocalAgentState?
    private var listener: ((LocalAgentEvent) -> Void)?

    func createEventStream() -> AsyncStream<LocalAgentEvent> {
        return AsyncStream<LocalAgentEvent> { continuation in
            listener = { event in
                continuation.yield(event)
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.listener = nil
            }
        }
    }

    init() {
        log.info("LocalAgentImplementation init")

        @Dependency(\.localAgentClientFactory) var clientFactory
        client = clientFactory.createLocalAgentClient()
        client.delegate = self
    }

    deinit {
        log.info("LocalAgentImplementation deinit")
        connection?.close()
    }

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws {
        connection?.close()

        log.debug(
            "Local agent connecting to \(configuration.hostname)",
            category: .localAgent,
            metadata: ["config": "\(configuration)"]
        )

        connection = try connectionFactory.makeLocalAgentConnection(configuration, data, client)
    }

    func disconnect() {
        connection?.close()
    }
}

extension LocalAgentImplementation: LocalAgentClientDelegate {
    func didReceive(event: LocalAgentEvent) {
        guard let listener else {
            log.assertionFailure("No listener available to receive event: \(event)")
            return
        }
        listener(event)
    }
}
