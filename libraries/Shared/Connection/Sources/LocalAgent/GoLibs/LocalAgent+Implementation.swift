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

import CoreConnection
import Dependencies
import Domain
import class GoLibs.LocalAgentFeatures

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
        client.delegate = self
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

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws(LAConnectionCreationError) {
        connection?.close()

        log.debug(
            "Creating local agent connection to \(configuration.hostname)",
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

    func set(features: LocalAgentFeatures) {
        guard let connection else {
            log.error("Failed to set Local Agent features: connection is nil")
            reportIssue("Failed to set Local Agent features: connection is nil")
            return
        }
        connection.setFeatures(features)
    }

    func retrieveNetShieldStats() {
        guard let connection else {
            log.error("Failed to fetch Netshield Stats: connection is nil")
            reportIssue("Failed to fetch Netshield Stats: connection is nil")
            return
        }
        connection.sendGetStatus(true)
    }

    func disconnect() {
        assert(connection != nil)
        connection?.close()
    }

    func setConnectivity(_ connectivity: Bool) {
        // we want to make sure we're not in a disconnected state due to a previous `close()` otherwise Go might panic!
        if let connection, connection.currentState != .disconnected {
            log.info("Sending connectivity update to \(connectivity)", category: .localAgent)
            connection.setConnectivity(connectivity)
        }
    }
}

extension LocalAgentImplementation: LocalAgentClientDelegate {
    func didReceive(event: LocalAgentEvent) {
        guard let streamContinuation else {
            log.error("Event ignored: stream continuation is nil")
            reportIssue("Event ignored: stream continuation is nil")
            return
        }
        streamContinuation.yield(event)
    }
}
