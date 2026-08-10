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

@CasePathable
public enum ConnectionIntentResolutionError: Error, Equatable {
    case serverChangeUnavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    case specificCountryUnavailable(countryCode: String)
    case secureCoreUnavailable
}

@CasePathable
public enum IntentResolutionError: Error, Equatable {
    case cancelled
    /// Asked to connect with a protocol that is no longer supported, such as OpenVPN.
    ///
    /// This error (should be) quite rare and will only happen when the user has stale configuration data from a
    /// previous version of the app.
    case unexpectedProtocol(VpnProtocol)
    case serverSelectionFailed(ServerSelector.SelectionError)
}

package struct ConnectionIntentResolver: DependencyKey {
    package internal(set) var resolve: @Sendable (ConnectionPreparationIntent) async throws(IntentResolutionError) -> ServerConnectionIntent
    package internal(set) var authorize: @Sendable (ConnectionPreparationIntent, VpnTier) throws(ConnectionIntentResolutionError) -> Void

    package init(
        resolve: @escaping @Sendable (ConnectionPreparationIntent) async throws(IntentResolutionError) -> ServerConnectionIntent,
        authorize: @escaping @Sendable (ConnectionPreparationIntent, VpnTier) throws(ConnectionIntentResolutionError) -> Void
    ) {
        self.resolve = resolve
        self.authorize = authorize
    }

    package static let liveValue: ConnectionIntentResolver = .init { intent throws(IntentResolutionError) in
        @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider
        @Dependency(\.serverSelector) var serverSelector
        @SharedReader(.userTier) var userTier: VpnTier?

        let server: Server
        do throws(ServerSelector.SelectionError) {
            // First, let's try to resolve the server we want to connect to.
            server = try serverSelector.select(intent.spec, userTier.orFree, intent.acceptableProtocols)
            log.info("Server selected: \(server.fullDescription)", category: .connection)
        } catch {
            throw .serverSelectionFailed(error)
        }

        if Task.isCancelled { throw .cancelled }

        let specifiedProtocol = intent.connectionProtocol ?? connectionFeatureProvider.connectionProtocol()
        log.debug("Resolved connection protocol", category: .connection, metadata: ["protocol": "\(specifiedProtocol)"])

        let protocolConfiguration: ProtocolConfiguration = switch specifiedProtocol {
        case .vpnProtocol(.ike):
            .ike
        case let .vpnProtocol(.wireGuard(transport)):
            .wireGuard(TunnelSettings(backend: .proTUN, transport: transport))
        case .smartProtocol:
            .wireGuard(TunnelSettings(backend: .proTUN, transport: nil))
        }

        return ServerConnectionIntent(
            spec: intent.spec,
            server: server,
            protocolConfiguration: protocolConfiguration,
            features: connectionFeatureProvider.connectionFeatures(),
            tunnelFeatures: connectionFeatureProvider.requestedFeatures()
        )
    } authorize: { intent, userTier throws(ConnectionIntentResolutionError) in
        // Paid users can always change servers.
        guard userTier.isFree else { return }

        @Dependency(\.serverChangeAuthorizer) var changeAuthorizer

        switch intent.spec.location {
        // Free users can always connect to the fastest server.
        case .any(.fastest):
            return

        // Free users can choose a random server a fixed number of times in a given interval.
        case .any(.random):
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
        case let .country(code, _), let .city(_, code, _), let .state(_, code, _), let .exact(_, _, _, _, code):
            throw .specificCountryUnavailable(countryCode: code)

        case .secureCore:
            throw .secureCoreUnavailable
        }
    }

    // TODO: Implement a testing client that performs no network requests but can give similar behaviour (VPNAPPL-2678)
    package static let testValue = liveValue
}

extension DependencyValues {
    var connectionIntentResolver: ConnectionIntentResolver {
        get { self[ConnectionIntentResolver.self] }
        set { self[ConnectionIntentResolver.self] = newValue }
    }
}
