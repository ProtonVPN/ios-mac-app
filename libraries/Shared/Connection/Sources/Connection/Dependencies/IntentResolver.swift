//
//  Created on 27/02/2025.
//
//  Copyright (c) 2025 Proton AG
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
import VPNShared

struct ConnectionIntentResolver: DependencyKey {
    private(set) var resolve: @Sendable (ConnectionPreparationIntent) async throws -> ServerConnectionIntent

    static let liveValue: ConnectionIntentResolver = .init { intent in
        @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider
        @Dependency(\.smartPortSelector) var portSelector

        let specifiedProtocol = intent.connectionProtocol ?? connectionFeatureProvider.connectionProtocol()
        log.debug("Resolved connection protocol", category: .connection, metadata: ["protocol": "\(specifiedProtocol)"])

        let portSelectionResult = try await portSelector.select(intent.server.endpoint, specifiedProtocol)
        try Task.checkCancellation()

        guard case .wireGuard(let transport) = portSelectionResult.chosenProtocol else {
            throw ConnectionError.unexpectedProtocol(portSelectionResult.chosenProtocol)
        }

        let ports = portSelectionResult.ports
        log.debug("WG transport and ports selected", category: .connection, metadata: ["transport": "\(transport)", "port": "\(ports)"])

        let features = connectionFeatureProvider.connectionFeatures()
        let tunnelFeatures = connectionFeatureProvider.tunnelFeatures()
        let tunnelSettings = TunnelSettings(transport: transport, ports: ports, features: tunnelFeatures)

        return ServerConnectionIntent(
            spec: intent.spec,
            server: intent.server,
            tunnelSettings: tunnelSettings,
            features: features
        )
    }

    // TODO: Implement a testing client that performs no network requests but can give similar behaviour (VPNAPPL-2678)
    static let testValue = liveValue
}

extension DependencyValues {
    var connectionIntentResolver: ConnectionIntentResolver {
        get { self[ConnectionIntentResolver.self] }
        set { self[ConnectionIntentResolver.self] = newValue }
    }
}
