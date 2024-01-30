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

    public var serverCount: () throws -> Int

    private var upsertServers: ([VPNServer]) throws -> Void
    private var deleteServers: (Int, Set<String>) throws -> Int

    private var upsertLoads: ([ContinuousServerProperties]) throws -> Void

    /// For UI - logicals grouped and annotated with aggregate logical info
    private var groups: ([VPNServerFilter], VPNServerGroupOrder) throws -> [ServerGroupInfo]
    /// For UI - logical annotated with aggregate server info
    private var servers: ([VPNServerFilter], VPNServerOrder) throws -> [Domain.ServerInfo]
    /// Connectable, includes logical + server, less suitable for UI
    private var server: ([VPNServerFilter], VPNServerOrder) throws -> VPNServer?

    /// Default unimplemented test value
    public static let testValue = ServerRepository()

    public init(
        serverCount: @escaping () throws -> Int = unimplemented(placeholder: 0),
        upsertServers: @escaping ([VPNServer]) throws -> Void = unimplemented(),
        server: @escaping ([VPNServerFilter], VPNServerOrder) throws -> VPNServer? = unimplemented(placeholder: nil),
        servers: @escaping ([VPNServerFilter], VPNServerOrder) throws -> [Domain.ServerInfo] = unimplemented(placeholder: []),
        deleteServers: @escaping (Int, Set<String>) throws -> Int = unimplemented(placeholder: 0),
        upsertLoads: @escaping ([ContinuousServerProperties]) throws -> Void = unimplemented(),
        groups: @escaping ([VPNServerFilter], VPNServerGroupOrder) throws -> [ServerGroupInfo] = unimplemented(placeholder: [])
    ) {
        self.serverCount = serverCount
        self.upsertServers = upsertServers
        self.server = server
        self.servers = servers
        self.deleteServers = deleteServers
        self.upsertLoads = upsertLoads
        self.groups = groups
    }
}

/// Public interface with labels
extension ServerRepository {
    public var isEmpty: Bool {
        get throws {
            try self.serverCount() == 0
        }
    }

    public func upsert(servers: [VPNServer]) throws -> Void {
        try upsertServers(servers)
    }

    public func delete(serversWithMinTier tier: Int, withIDsNotIn ids: Set<String>) throws -> Int {
        try deleteServers(tier, ids)
    }

    public func upsert(loads: [ContinuousServerProperties]) throws -> Void {
        try upsertLoads(loads)
    }

    public func getGroups(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerGroupOrder = .localizedCountryNameAscending
    ) throws -> [ServerGroupInfo] {
        try groups(filters, order)
    }

    public func getFirstServer(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) throws -> VPNServer? {
        try server(filters, order)
    }

    public func getServers(
        filteredBy filters: [VPNServerFilter],
        orderedBy order: VPNServerOrder
    ) throws -> [ServerInfo] {
        try servers(filters, order)
    }
}

extension DependencyValues {
    public var serverRepository: ServerRepository {
        get { self[ServerRepository.self] }
        set { self[ServerRepository.self] = newValue }
    }
}
