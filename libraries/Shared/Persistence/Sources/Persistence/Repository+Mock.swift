//
//  Created on 17/01/2024.
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

import Domain

import XCTestDynamicOverlay

#if DEBUG

/// Provides callbacks required to maintain legacy tests
///
/// Historically, a MockServerRepository partially implemented the set of features that the real thing provides, but
/// it was dropped in favour of using a wrapper that provides necessary callbacks to increase test coverage.
public class ServerRepositoryWrapper {

    public var didStoreServers: (([VPNServer]) -> Void)?
    public var didUpdateLoads: (([VPNServer]) -> Void)?

    public var repository: ServerRepository

    public init(repository: ServerRepository) {
        self.repository = repository
    }

    public var serverCount: Int { get throws { try repository.serverCount() } }

    public func getFirstServer(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) throws -> VPNServer? {
       try repository.getFirstServer(filteredBy: filters, orderedBy: order)
    }

    public func getServers(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) throws -> [ServerInfo] {
        try repository.getServers(filteredBy: filters, orderedBy: order)
    }

    public func upsert(servers: [VPNServer]) throws {
        try repository.upsert(servers: servers)
        didStoreServers?(servers)
    }

    public func deleteServers(withMinTier minTier: Int, withIDsNotIn ids: Set<String>) throws -> Int {
        return try repository.delete(serversWithMinTier: minTier, withIDsNotIn: ids)
    }

    public func upsert(loads: [ContinuousServerProperties]) throws {
        try repository.upsert(loads: loads)
        let updatedServers = try loads.compactMap {
            try repository.getFirstServer(filteredBy: [.logicalID($0.serverId)], orderedBy: .none)
        }
        didUpdateLoads?(updatedServers)
    }
}

extension ServerRepository {
    /// Returns a `ServerRepository` which itself wraps a `ServerRepositoryWrapper`. This allows integration tests to
    /// use real SQL based repository functions, while exposing callbacks such as `didStoreServers`.
    ///
    /// Suitable for integration tests, when large changes occur within the repository, or when callbacks are required
    /// such as whenever servers are inserted.
    ///
    /// Unit tests should instead construct a minimal mock repository.
    public static func wrapped(wrappedWith wrapper: ServerRepositoryWrapper) -> Self {
        return .init(
            serverCount: { try wrapper.serverCount },
            upsertServers: wrapper.upsert,
            server: wrapper.getFirstServer,
            servers: wrapper.getServers,
            deleteServers: wrapper.deleteServers,
            upsertLoads: wrapper.upsert
        )
    }
}

#endif
