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

import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import Persistence

/// Stores the server list returned by the logicals endpoint.
///
/// This is the write side of the conditional request contract that ``VpnApiService`` reads when it builds a
/// `LogicalsRequest`: it records the response's last modified timestamp so that subsequent requests can be answered
/// with a cheap "not modified". It also broadcasts ``ServerListUpdateNotification`` so observers reload their servers.
///
/// Everything else about storing servers - purging stale ones, tracking when to fetch the full list again - belongs to
/// ``ServerRepository``, so reach for `@Dependency(\.serverRepository)` directly rather than widening this client.
@DependencyClient
public struct ServerListUpdater: Sendable {
    /// Stores the servers from a modified logicals response.
    ///
    /// - Parameters:
    ///   - servers: The servers the response contained. These become the complete set of servers up to the tier that
    ///   was requested, so any server missing from them is purged.
    ///   - freeServersOnly: Whether the request was capped at the free tier. Paid servers are left untouched when it
    ///   was, since a free tier response says nothing about them.
    ///   - lastModifiedAt: The response's last modified timestamp, used for subsequent conditional requests.
    public var update: @Sendable (_ servers: [VPNServer], _ freeServersOnly: Bool, _ lastModifiedAt: String?) -> Void
}

extension ServerListUpdater: DependencyKey {
    public static let liveValue = ServerListUpdater(
        update: { servers, freeServersOnly, lastModifiedAt in
            @Dependency(\.serverRepository) var repository

            // If we're only fetching a subset of servers up to a certain tier, we must not purge stale servers above it
            let maxTier = freeServersOnly ? VpnTier.free.rawValue : VpnTier.internal.rawValue

            #if DEBUG
                // Somewhat expensive O(n) sanity check
                let containsFreeServersOnly = servers.allSatisfy(\.logical.tier.isFree)
                if containsFreeServersOnly != freeServersOnly {
                    log.warning("Server list tier does not match the requested tier", category: .api, metadata: [
                        "containsFreeServersOnly": "\(containsFreeServersOnly)",
                        "freeServersOnly": "\(freeServersOnly)",
                    ])
                }
            #endif

            let deletedServerCount = repository.replace(servers: servers, maxTier: maxTier)
            log.info("Updated servers", category: .persistence, metadata: [
                "updatedServerCount": "\(servers.count)",
                "deletedServerCount": "\(deletedServerCount)",
                "maxTier": "\(maxTier)",
            ])

            repository.recordSuccessfulRefresh()

            // Store the last modified value, so we can use it when making subsequent logicals requests, to take
            // advantage of the `If-Modified-Since` header
            if VPNFeatureFlagType.timestampedLogicals.enabled, let lastModifiedAt {
                // A full response is also a valid baseline for a subsequent free tier request, but not the reverse
                repository.setMetadata(lastModifiedAt, for: .lastModifiedFree)
                if !freeServersOnly {
                    repository.setMetadata(lastModifiedAt, for: .lastModifiedAll)
                }
            }

            NotificationCenter.default.post(ServerListUpdateNotification(data: .servers), object: nil)
        }
    )

    /// We don't mind using the live dependency by default in our current test suite, given that we always control
    /// `serverRepository` (it has no actual implementations inside `testValue`)
    public static let testValue = liveValue
}

#if DEBUG
    public extension ServerListUpdater {
        /// Drops server list updates on the floor, for tests that drive a refresh but don't assert on its servers.
        static var noOp: ServerListUpdater {
            ServerListUpdater(update: { _, _, _ in })
        }
    }
#endif

public extension DependencyValues {
    var serverListUpdater: ServerListUpdater {
        get { self[ServerListUpdater.self] }
        set { self[ServerListUpdater.self] = newValue }
    }
}
