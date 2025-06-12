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

import ComposableArchitecture
import CoreConnection
import Dependencies
import Domain
import Foundation
import VPNShared

/// Duplicates logic in `ConnectionAuthorizer` in `LegacyCommon` for now, but can add more resolution errors later.
@CasePathable
public enum ConnectionIntentResolutionError: Error, Equatable {
    case serverChangeUnavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    case specificCountryUnavailable(countryCode: String)
    case secureCoreUnavailable
}

struct ConnectionIntentResolver: DependencyKey, Sendable {
    let resolve: @Sendable (ConnectionPreparationIntent) async throws -> ServerConnectionIntent
    let authorize: @Sendable (ConnectionPreparationIntent, Int) throws(ConnectionIntentResolutionError) -> ()

    static let liveValue: ConnectionIntentResolver = .init { intent in
        @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider
        @Dependency(\.smartPortSelector) var portSelector

        let specifiedProtocol = intent.connectionProtocol ?? connectionFeatureProvider.connectionProtocol()
        log.debug("Resolved connection protocol", category: .connection, metadata: ["protocol": "\(specifiedProtocol)"])

        let portSelectionResult = try await portSelector.select(intent.server.endpoint, specifiedProtocol)
        try Task.checkCancellation()

        guard case let .wireGuard(transport) = portSelectionResult.chosenProtocol else {
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
    } authorize: { intent, userTier throws(ConnectionIntentResolutionError) in
        // Paid users can always change servers.
        guard userTier.isFreeTier else { return }

        @Dependency(\.serverChangeAuthorizer) var changeAuthorizer

        switch intent.spec.location {
        // Free users can always connect to the fastest server.
        case .fastest:
            return

        // Free users can choose a random server a fixed number of times in a given interval.
        case .random:
            switch changeAuthorizer.serverChangeAvailability() {
            case .available:
                return
            case let .unavailable(date, duration, exhaustedSkips):
                throw .serverChangeUnavailable(until: date, duration: duration, exhaustedSkips: exhaustedSkips)
            }

        case let .gateway(name):
            log.assertionFailure("Free user requested connection to gateway", category: .connection)
            throw .specificCountryUnavailable(countryCode: name)

        // Free users aren't allowed to choose an exact server.
        case let .region(code), let .exact(_, _, _, _, code):
            throw .specificCountryUnavailable(countryCode: code)

        case .secureCore:
            throw .secureCoreUnavailable
        }
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
