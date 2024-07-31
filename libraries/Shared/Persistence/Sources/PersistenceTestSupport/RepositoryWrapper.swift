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
import Persistence

/// Provides callbacks required to maintain legacy tests
///
/// Historically, a `MockServerRepository` partially implemented the set of features that the real thing provides, but
/// it was dropped in favour of using a wrapper around the real implementation, which provides the necessary callbacks.
public final class ServerRepositoryWrapper {

    public var didStoreServers: (([VPNServer]) -> Void)?
    public var didUpdateLoads: (([VPNServer]) -> Void)?

    public let repository: ServerRepository

    public init(repository: ServerRepository) {
        self.repository = repository
    }

    public var serverCount: Int { repository.serverCount() }
    public var countryCount: Int { repository.countryCount() }

    public func getFirstServer(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) -> VPNServer? {
        repository.getFirstServer(filteredBy: filters, orderedBy: order)
    }

    public func getServers(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) -> [ServerInfo] {
        repository.getServers(filteredBy: filters, orderedBy: order)
    }

    public func upsert(servers: [VPNServer]) {
        repository.upsert(servers: servers)
        didStoreServers?(servers)
    }

    public func deleteServers(withIDsNotIn ids: Set<String>, maxTier: Int) -> Int {
        return repository.delete(serversWithIDsNotIn: ids, maxTier: maxTier)
    }

    public func upsert(loads: [ContinuousServerProperties]) {
        repository.upsert(loads: loads)
        let updatedServers = loads.compactMap {
            repository.getFirstServer(filteredBy: [.logicalID($0.serverId)], orderedBy: .none)
        }
        didUpdateLoads?(updatedServers)
    }

    public func getGroups(
        filteredBy filters: [VPNServerFilter],
        orderedBy groupOrder: VPNServerGroupOrder = .localizedCountryNameAscending
    ) -> [ServerGroupInfo] {
        repository.getGroups(filteredBy: filters, orderedBy: groupOrder)
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
            serverCount: { wrapper.serverCount },
            countryCount: { wrapper.countryCount },
            upsertServers: wrapper.upsert,
            server: wrapper.getFirstServer,
            servers: wrapper.getServers,
            deleteServers: wrapper.deleteServers,
            upsertLoads: wrapper.upsert,
            groups: wrapper.getGroups,
            getMetadata: wrapper.repository.getMetadata,
            setMetadata: wrapper.repository.setMetadata
        )
    }
}
