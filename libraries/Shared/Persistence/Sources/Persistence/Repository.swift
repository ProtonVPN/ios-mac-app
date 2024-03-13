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

    public var insertServers: ([VPNServer]) throws -> Void
    public var deleteServers: (Set<String>) throws -> Void

    public var updateLoads: ([ContinuousServerProperties]) throws -> Void

    /// For UI - logicals grouped and annotated with aggregate logical info
    public var groups: ([VPNServerFilter]) throws -> [ServerGroupInfo]
    /// For UI - logical annotated with aggregate server info
    public var servers: ([VPNServerFilter], VPNServerOrder) throws -> [Domain.ServerInfo]
    /// Connectable, includes logical + server, less suitable for UI
    public var server: ([VPNServerFilter], VPNServerOrder) throws -> VPNServer?

    /// Default unimplemented test value
    public static let testValue = ServerRepository()

    public init(
        serverCount: @escaping () throws -> Int = unimplemented(placeholder: 0),
        insertServers: @escaping ([VPNServer]) throws -> Void = unimplemented(),
        server: @escaping ([VPNServerFilter], VPNServerOrder) throws -> VPNServer? = unimplemented(placeholder: nil),
        servers: @escaping ([VPNServerFilter], VPNServerOrder) throws -> [Domain.ServerInfo] = unimplemented(placeholder: []),
        deleteServers: @escaping (Set<String>) throws -> Void = unimplemented(),
        updateLoads: @escaping ([ContinuousServerProperties]) throws -> Void = unimplemented(),
        groups: @escaping ([VPNServerFilter]) throws -> [ServerGroupInfo] = unimplemented(placeholder: [])
    ) {
        self.serverCount = serverCount
        self.insertServers = insertServers
        self.server = server
        self.servers = servers
        self.deleteServers = deleteServers
        self.updateLoads = updateLoads
        self.groups = groups
    }
}

extension ServerRepository {
    public var isEmpty: Bool {
        get throws {
            try self.serverCount() == 0
        }
    }
}

extension DependencyValues {
    public var serverRepository: ServerRepository {
        get { self[ServerRepository.self] }
        set { self[ServerRepository.self] = newValue }
    }
}
