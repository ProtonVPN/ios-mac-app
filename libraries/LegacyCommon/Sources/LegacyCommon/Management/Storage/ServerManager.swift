//
//  Created on 09/04/2024.
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
import ProtonCoreFeatureFlags

import Dependencies

import Domain
import Persistence

public struct ServerManager: DependencyKey {
    private var updateServers: @Sendable (
        _ servers: [VPNServer],
        _ freeServersOnly: Bool,
        _ lastModifiedAt: String?
    ) -> Void

    private var purgeServers: () -> Void
    private var _shouldFetchFullServerList: () -> Bool

    private static var consecutiveSuccessfulRefreshes: Int {
        @Dependency(\.serverRepository) var repository
        guard let storedValue = repository.getMetadata(.consecutiveSuccessfulRefreshes) else {
            return 0
        }
        guard let existingRefreshes = Int(storedValue) else {
            log.debug("Stored value is not an Int", category: .persistence, metadata: ["value": "\(storedValue)"])
            return 0
        }
        return existingRefreshes
    }

    init(
        updateServers: @Sendable @escaping (_: [VPNServer], _: Bool, _: String?) -> Void,
        purgeServers: @Sendable @escaping () -> Void,
        shouldFetchFullServerList: @Sendable @escaping () -> Bool
    ) {
        self.updateServers = updateServers
        self.purgeServers = purgeServers
        self._shouldFetchFullServerList = shouldFetchFullServerList
    }

    public static let liveValue: ServerManager = .init(
        updateServers: { servers, freeServersOnly, lastModified in
            @Dependency(\.serverRepository) var repository
            // If we're only fetching a subset of servers up to a certain tier, we must not purge stale servers above it
            let maxTierToPurge: Int = freeServersOnly ? .freeTier : .internalTier
            let newServerIDs = Set(servers.map(\.id))

            let refreshes = (Self.consecutiveSuccessfulRefreshes + 1) % 10
            repository.setMetadata(String(refreshes), for: .consecutiveSuccessfulRefreshes)

            #if DEBUG
                // Somewhat expensive O(n) sanity check
                let containsFreeServersOnly = servers.allSatisfy { $0.logical.tier == 0 }
                if containsFreeServersOnly != freeServersOnly {
                    log.warning("\(containsFreeServersOnly) != \(freeServersOnly)")
                }
            #endif

            let deletedServerCount = repository.delete(serversWithIDsNotIn: newServerIDs, maxTier: maxTierToPurge)
            log.info("Purged stale servers", category: .persistence, metadata: [
                "deletedServerCount": "\(deletedServerCount)",
                "maxTier": "\(maxTierToPurge))",
            ])

            repository.upsert(servers: servers)
            log.info("Updated servers", category: .persistence, metadata: ["updatedServerCount": "\(servers.count)"])

            // Store the last modified value, so we can use it when making subsequent logicals requests, to take
            // advantage of the `If-Modified-Since` header
            if VPNFeatureFlagType.timestampedLogicals.enabled, let lastModified {
                repository.setMetadata(lastModified, for: .lastModifiedFree)
                if !freeServersOnly {
                    repository.setMetadata(lastModified, for: .lastModifiedAll)
                }
            }

            NotificationCenter.default.post(ServerListUpdateNotification(data: .servers), object: nil)
        },
        purgeServers: {
            @Dependency(\.serverRepository) var repository
            _ = repository.delete(serversWithIDsNotIn: [], maxTier: .max)
            repository.deleteMetadata(for: .lastModifiedFree)
            repository.deleteMetadata(for: .lastModifiedAll)
            repository.deleteMetadata(for: .consecutiveSuccessfulRefreshes)
        },
        shouldFetchFullServerList: {
            // Returning false here means we limit the maximum server tier received to our current tier.
            // The full server list should be fetched every tenth time, including the first time.
            // When the database is cleared, `consecutiveSuccessfulRefreshes` will be equal to zero, and the full
            // server list will be fetched.
            (consecutiveSuccessfulRefreshes % 10) == 0
        }
    )

    /// We don't mind using the live dependency by default in our current test suite, given that we always control
    /// `serverRepository` (it has no actual implementations inside `testValue`)
    public static let testValue = liveValue
}

public extension ServerManager {
    func update(servers: [VPNServer], freeServersOnly: Bool, lastModifiedAt: String?) {
        updateServers(servers, freeServersOnly, lastModifiedAt)
    }

    func purgeAllServers() {
        purgeServers()
    }

    var shouldFetchFullServerList: Bool {
        _shouldFetchFullServerList()
    }
}

#if DEBUG
    public extension ServerManager {
        static var noOp: ServerManager {
            ServerManager(
                updateServers: { _, _, _ in },
                purgeServers: {},
                shouldFetchFullServerList: { true }
            )
        }
    }
#endif

public extension DependencyValues {
    var serverManager: ServerManager {
        get { self[ServerManager.self] }
        set { self[ServerManager.self] = newValue }
    }
}
