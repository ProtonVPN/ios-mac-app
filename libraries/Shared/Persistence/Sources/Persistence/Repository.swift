//
//  Created on 2023-11-30.
//
//  Copyright (c) 2023 Proton AG
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
import DependenciesMacros
import Domain
import Foundation
import IssueReporting

/// Non-async interface for now, since even disk-based SQLite is super fast and we can always load in an in-memory DB
/// to perform queries on in the future if performance becomes an issue.
///
/// This minimal interface should be expanded and/or split into separate repositories, when new requirements arise from
/// new user interface/new API functionality. Future extensions could include:
///  - Servers interface for adding/updating/deleting physical servers by ID without touching logicals
@DependencyClient
public struct ServerRepository: Sendable {
    public var serverCount: @Sendable () -> Int = { 0 }
    public var countryCount: @Sendable () -> Int = { 0 }

    public var upsertServers: @Sendable ([VPNServer]) -> Void
    public var deleteServers: @Sendable (Set<String>, Int) -> Int = { _, _ in 0 }

    public var upsertLoads: @Sendable ([ContinuousServerProperties]) -> Void

    /// For UI - logicals grouped and annotated with aggregate logical info
    public var groups: @Sendable ([VPNServerFilter], VPNServerGrouping, VPNServerGroupOrder) -> [ServerGroupInfo] = { _, _, _ in [] }
    /// For UI - logical annotated with aggregate server info
    public var servers: @Sendable ([VPNServerFilter], VPNServerOrder) -> [Domain.ServerInfo] = { _, _ in [] }
    /// Connectable, includes logical + server, less suitable for UI
    public var server: @Sendable ([VPNServerFilter], VPNServerOrder) -> VPNServer?

    public var getMetadata: @Sendable (DatabaseMetadata.Key) -> String?
    public var setMetadata: @Sendable (DatabaseMetadata.Key, String?) -> Void

    /// Close the underlying database connection. It is considered a fatal error to continue using other repository
    /// functions after invoking this.
    public var closeConnection: @Sendable () throws -> Void
}

/// Public interface with labels
public extension ServerRepository {
    var isEmpty: Bool {
        serverCount() == 0
    }

    func upsert(servers: [VPNServer]) {
        upsertServers(servers)
    }

    func delete(serversWithIDsNotIn ids: Set<String>, maxTier: Int) -> Int {
        deleteServers(ids, maxTier)
    }

    func upsert(loads: [ContinuousServerProperties]) {
        upsertLoads(loads)
    }

    func getGroups(
        filteredBy filters: [VPNServerFilter],
        groupedBy grouping: VPNServerGrouping,
        orderedBy order: VPNServerGroupOrder = .localizedCountryNameAscending
    ) -> [ServerGroupInfo] {
        groups(filters, grouping, order)
    }

    func getFirstServer(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) -> VPNServer? {
        server(filters, order)
    }

    func getServers(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) -> [ServerInfo] {
        servers(filters, order)
    }

    func setMetadata(_ value: String, for key: DatabaseMetadata.Key) {
        setMetadata(key, value)
    }

    func deleteMetadata(for key: DatabaseMetadata.Key) {
        setMetadata(key, nil)
    }
}

public extension ServerRepository {
    var roundedServerCount: Int {
        serverCount().roundedServerCount()
    }
}

extension BinaryInteger {
    /// We're rounding the servers here in a "special" way. It's because we want to be exact in this non-exactness 😄
    /// In upsells we say for example 4400+ servers. The + indicates being there more than 4400 servers.
    /// So if we have exactly 4400, we'd be lying to say we have 4400+ servers.
    func roundedServerCount() -> Self {
        guard self > 100 else { return self }
        let remainder = self % 100
        if remainder == 0 {
            return self - 100
        } else {
            return self - remainder
        }
    }
}

public extension DependencyValues {
    var serverRepository: ServerRepository {
        get { self[ServerRepositoryKey.self] }
        set { self[ServerRepositoryKey.self] = newValue }
    }
}
