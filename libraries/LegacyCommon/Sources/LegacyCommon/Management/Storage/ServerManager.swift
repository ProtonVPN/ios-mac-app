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

    public static let liveValue: ServerManager = ServerManager(
        updateServers: { servers, freeServersOnly, lastModified in
            @Dependency(\.serverRepository) var repository
            // If we're only fetching a subset of servers up to a certain tier, we must not purge stale servers above it
            let maxTierToPurge: Int = freeServersOnly ? .freeTier : .internalTier
            let newServerIDs = Set(servers.map(\.id))

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
                "maxTier": "\(maxTierToPurge))"
            ])

            repository.upsert(servers: servers)

            // Store the last modified value, so we can use it when making subsequent logicals requests, to take
            // advantage of the `If-Modified-Since` header
            if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.timestampedLogicals), let lastModified {
                repository.setMetadata(lastModified, for: .lastModifiedFree)
                if !freeServersOnly {
                    repository.setMetadata(lastModified, for: .lastModifiedAll)
                }
            }

            NotificationCenter.default.post(ServerListUpdateNotification(data: .servers), object: nil)
        }
    )

    /// We don't mind using the live dependency by default in our current test suite, given that we always control
    /// `serverRepository` (it has no actual implementations inside `testValue`)
    public static let testValue = liveValue
}

extension ServerManager {
    public func update(servers: [VPNServer], freeServersOnly: Bool, lastModifiedAt: String?) {
        updateServers(servers, freeServersOnly, lastModifiedAt)
    }
}

extension DependencyValues {
    public var serverManager: ServerManager {
        get { self[ServerManager.self] }
        set { self[ServerManager.self] = newValue }
    }
}
