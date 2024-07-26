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

import Foundation

import Dependencies

import Domain

/// Non-async interface for now, since even disk-based SQLite is super fast and we can always load in an in-memory DB
/// to perform queries on in the future if performance becomes an issue.
///
/// This minimal interface should be expanded and/or split into separate repositories, when new requirements arise from
/// new user interface/new API functionality. Future extensions could include:
///  - Servers interface for adding/updating/deleting physical servers by ID without touching logicals
public struct ServerRepository: DependencyKey {

    public var serverCount: () -> Int
    public var countryCount: () -> Int

    private var upsertServers: ([VPNServer]) -> Void
    private var deleteServers: (Set<String>, Int) -> Int

    private var upsertLoads: ([ContinuousServerProperties]) -> Void

    /// For UI - logicals grouped and annotated with aggregate logical info
    private var groups: ([VPNServerFilter], VPNServerGroupOrder) -> [ServerGroupInfo]
    /// For UI - logical annotated with aggregate server info
    private var servers: ([VPNServerFilter], VPNServerOrder) -> [Domain.ServerInfo]
    /// Connectable, includes logical + server, less suitable for UI
    private var server: ([VPNServerFilter], VPNServerOrder) -> VPNServer?

    public var getMetadata: (DatabaseMetadata.Key) -> String?
    public var setMetadata: (DatabaseMetadata.Key, String?) -> Void

    /// Close the underlying database connection. It is considered a fatal error to continue using other repository
    /// functions after invoking this.
    public var closeConnection: () throws -> Void

    /// Default unimplemented test value
    ///
    /// `serverCount` and `countryCount` are invoked in many places in `LegacyCommon` where dependencies are not
    /// propagated across escaping closures. For now, let's provide implementations to prevent failing legacy tests.
    public static let testValue = ServerRepository(serverCount: { -1 }, countryCount: { -1 })

    public init(
        serverCount: @escaping () -> Int = unimplemented(placeholder: 0),
        countryCount: @escaping () -> Int = unimplemented(placeholder: 0),
        upsertServers: @escaping ([VPNServer]) -> Void = unimplemented(),
        server: @escaping ([VPNServerFilter], VPNServerOrder) -> VPNServer? = unimplemented(placeholder: nil),
        servers: @escaping ([VPNServerFilter], VPNServerOrder) -> [Domain.ServerInfo] = unimplemented(placeholder: []),
        deleteServers: @escaping (Set<String>, Int) -> Int = unimplemented(placeholder: 0),
        upsertLoads: @escaping ([ContinuousServerProperties]) -> Void = unimplemented(),
        groups: @escaping ([VPNServerFilter], VPNServerGroupOrder) -> [ServerGroupInfo] = unimplemented(placeholder: []),
        getMetadata: @escaping (DatabaseMetadata.Key) -> String? = unimplemented(placeholder: nil),
        setMetadata: @escaping (DatabaseMetadata.Key, String?) -> Void = unimplemented(),
        closeConnection: @escaping () throws -> Void = unimplemented()
    ) {
        self.serverCount = serverCount
        self.countryCount = countryCount
        self.upsertServers = upsertServers
        self.server = server
        self.servers = servers
        self.deleteServers = deleteServers
        self.upsertLoads = upsertLoads
        self.groups = groups
        self.getMetadata = getMetadata
        self.setMetadata = setMetadata
        self.closeConnection = closeConnection
    }
}

/// Public interface with labels
extension ServerRepository {
    public var isEmpty: Bool {
        get {
            self.serverCount() == 0
        }
    }

    public func upsert(servers: [VPNServer]) -> Void {
        upsertServers(servers)
    }

    public func delete(serversWithIDsNotIn ids: Set<String>, maxTier: Int) -> Int {
        deleteServers(ids, maxTier)
    }

    public func upsert(loads: [ContinuousServerProperties]) -> Void {
        upsertLoads(loads)
    }

    public func getGroups(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerGroupOrder = .localizedCountryNameAscending
    ) -> [ServerGroupInfo] {
        groups(filters, order)
    }

    public func getFirstServer(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) -> VPNServer? {
        server(filters, order)
    }

    public func getServers(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) -> [ServerInfo] {
        servers(filters, order)
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

extension DependencyValues {
    public var serverRepository: ServerRepository {
        get { self[ServerRepository.self] }
        set { self[ServerRepository.self] = newValue }
    }
}
