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

import Dependencies
import Domain
import CoreConnection

final class LocalAgentImplementation: LocalAgent {
    @Dependency(\.localAgentConnectionFactory) var connectionFactory

    private(set) var netShieldType: NetShieldType = .off

    private let client: LocalAgentClient
    private var connection: LocalAgentConnection?
    private var streamContinuation: AsyncStream<LocalAgentEvent>.Continuation?

    init() {
        log.info("LocalAgentImplementation init")

        @Dependency(\.localAgentClientFactory) var clientFactory
        self.client = clientFactory.createLocalAgentClient()
        self.client.delegate = self
    }

    deinit {
        log.info("LocalAgentImplementation deinit")
        connection?.close()
    }

    func createEventStream() -> AsyncStream<LocalAgentEvent> {
        let tuple = AsyncStream<LocalAgentEvent>.makeStream()
        streamContinuation = tuple.continuation
        return tuple.stream
    }

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws {
        connection?.close()

        log.debug(
            "Local agent connecting to \(configuration.hostname)",
            category: .localAgent,
            metadata: ["config": "\(configuration)"]
        )

        connection = try connectionFactory.makeLocalAgentConnection(configuration, data, client)

        netShieldType = configuration.features.netshield

        // Initiate at least one fetch of NetShield Stats
        if netShieldType.shouldObserveNetShieldStats {
            retrieveNetShieldStats()
        }
    }

    func retrieveNetShieldStats() {
        connection?.sendGetStatus(true)
    }

    func disconnect() {
        connection?.close()
    }
}

extension LocalAgentImplementation: LocalAgentClientDelegate {
    func didReceive(event: LocalAgentEvent) {
        streamContinuation?.yield(event)
    }
}
