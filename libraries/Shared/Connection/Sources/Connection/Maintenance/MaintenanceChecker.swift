//
//  Created on 30/07/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import CommonNetworking
import CoreConnection
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import Sharing
import VPNAppCore

/// Asks the API whether the server we're currently connected to is about to go into maintenance.
///
/// Owns only the question, not the answer: scheduling the checks and reacting to a positive one belongs to
/// ``MaintenanceFeature``.
@DependencyClient
public struct MaintenanceChecker: Sendable {
    /// Whether the currently connected server is going into maintenance.
    ///
    /// Refreshes the stored server list along the way, since a server entering maintenance means the list we hold is
    /// stale. Returns `false` when there is nothing to check - no active connection, or a healthy server.
    public var isCurrentServerUnderMaintenance: @Sendable () async throws -> Bool
}

extension MaintenanceChecker: DependencyKey {
    public static let liveValue = MaintenanceChecker(
        isCurrentServerUnderMaintenance: {
            @Dependency(\.vpnApiClient) var vpnApiClient
            @SharedReader(.connectionState) var connectionState: ConnectionState

            guard let activeServer = connectionState.resolvedServer else {
                log.info("No active connection", category: .app)
                return false
            }

            guard connectionState.isConnectedOrConnecting else {
                log.info("VPN Not connected", category: .app)
                return false
            }

            let vpnServerState = try await vpnApiClient.serverState(serverId: activeServer.endpoint.id)
            guard vpnServerState.status != 1 else {
                return false
            }

            // This doesn't need to be a strict check, it's just to reduce load on the API
            @SharedReader(.userTier) var userTier
            @SharedReader(.userLocation) var userLocation
            let location = userLocation?.location

            let result = try await vpnApiClient.serverInfo(
                ip: (location?.ip).flatMap { TruncatedIp(ip: $0) },
                countryCode: location?.country,
                scope: userTier.isFree ? .freeTier : .allTiers
            )

            @Dependency(\.serverListUpdater) var serverListUpdater

            switch result {
            case let .modified(at: modifiedAt, servers: servers, scope: scope, language: language):
                serverListUpdater.update(
                    servers: servers,
                    scope: scope,
                    lastModifiedAt: modifiedAt,
                    language: language
                )

            case let .notModified(lastModified, scope):
                log.debug(
                    "Servers not modified",
                    category: .api,
                    metadata: ["LastModified": "\(optional: lastModified)"]
                )
                serverListUpdater.recordUnchanged(
                    scope: scope,
                    lastModifiedAt: lastModified
                )
            }

            return true
        }
    )
}

public extension DependencyValues {
    var maintenanceChecker: MaintenanceChecker {
        get { self[MaintenanceChecker.self] }
        set { self[MaintenanceChecker.self] = newValue }
    }
}
