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

/// Stores the server list returned by the logicals endpoint (not responsible for lookup, check out
/// ``ServerRepository``).
@DependencyClient
public struct ServerListUpdater: Sendable {
    /// Stores the servers from a modified logicals response.
    ///
    /// - Parameters:
    ///   - servers: The servers the response contained. These become the complete set of servers up to the
    ///   tier that was requested, so any server missing from them is purged.
    ///   - scope: Which servers were asked for. A free tier response leaves the paid servers untouched, since it says
    ///   nothing about them, and each scope records its own conditional request baseline.
    ///   - lastModifiedAt: The response's last modified timestamp, used for subsequent conditional requests.
    ///   - language: The `x-pm-locale` language the request was made with, which is the language the response's
    ///   translated names arrived in.
    public var update: @Sendable (
        _ servers: [VPNServer],
        _ scope: ServerListScope,
        _ lastModifiedAt: String?,
        _ language: String
    ) -> Void
}

extension ServerListUpdater: DependencyKey {
    public static let liveValue = ServerListUpdater(
        update: { servers, scope, lastModifiedAt, language in
            @Dependency(\.serverRepository) var repository

            // If we're only fetching a subset of servers up to a certain tier, we must not purge stale servers above it
            let maxTier = scope.coversEveryTier ? VpnTier.internal.rawValue : VpnTier.free.rawValue

            #if DEBUG
                // Somewhat expensive O(n) sanity check
                let containsFreeServersOnly = servers.allSatisfy(\.logical.tier.isFree)
                if containsFreeServersOnly != scope.isCappedAtFreeTier {
                    log.warning("Server list tier does not match the requested tier", category: .api, metadata: [
                        "containsFreeServersOnly": "\(containsFreeServersOnly)",
                        "scope": "\(scope)",
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
            if let lastModifiedAt {
                repository.recordServerList(scope: scope, lastModifiedAt: lastModifiedAt)
            }

            // A response that covers every tier carries every translated name, so it settles which language the
            // stored names are in. A free tier response cannot, since it says nothing about the paid servers and
            // leaves them under the names they already had.
            if scope.coversEveryTier {
                repository.setMetadata(language, for: .translationsLanguage)
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
            ServerListUpdater(update: { _, _, _, _ in })
        }
    }
#endif

public extension DependencyValues {
    var serverListUpdater: ServerListUpdater {
        get { self[ServerListUpdater.self] }
        set { self[ServerListUpdater.self] = newValue }
    }
}
