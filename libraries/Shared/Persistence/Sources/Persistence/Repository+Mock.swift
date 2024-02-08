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
public class MockServerStorage {

    public var servers: [String: VPNServer]

    public var shouldFailOnMissingServerDuringLoadsUpdate = true

    public var didStoreServers: (([VPNServer]) -> Void)?
    public var didUpdateLoads: (([VPNServer]) -> Void)?

    public init(servers: [VPNServer] = []) {
        self.servers = servers.reduce(into: [:]) { result, server in
            result[server.logical.id] = server
        }
    }

    var serverCount: Int { servers.count }

    private func servers(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) -> [VPNServer] {
        return filters.reduce(Array(servers.values)) { servers, filter in
            switch filter {
            case .logicalID(let id):
                return servers.filter { $0.logical.id == id }
            default:
                XCTFail("Unimplemented server filter: \(filter)")
                return servers
            }
        }
    }

    func upsert(servers: [VPNServer]) {
        // Care - `servers` argument shadows instance variable of the same name
        servers.forEach {
            self.servers[$0.logical.id] = $0
        }
        didStoreServers?(servers)
    }

    func getFirstServer(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) -> VPNServer? {
        return servers(filteredBy: filters, orderedBy: order).first
    }

    func getServers(filteredBy filters: [VPNServerFilter], orderedBy order: VPNServerOrder) -> [ServerInfo] {
        return servers(filteredBy: filters, orderedBy: order)
            .map { ServerInfo(logical: $0.logical, protocolSupport: $0.supportedProtocols) }
    }

    func deleteServers(withMinTier minTier: Int, withIDsNotIn ids: Set<String>) -> Int {
        let initialServerCount = servers.count
        servers = servers.filter { (id, server) in
            ids.contains(id) || server.logical.tier < minTier
        }
        return initialServerCount - servers.count
    }

    func upsert(loads: [ContinuousServerProperties]) {
        let updatedServers: [VPNServer] = loads.compactMap { dynamicInfo in
            let serverID = dynamicInfo.serverId
            guard let server = servers[serverID] else {
                if shouldFailOnMissingServerDuringLoadsUpdate {
                    XCTFail("Failed to update dynamic info - no server with ID \(serverID)")
                }
                return nil
            }
            let updatedServer = server.with(dynamicInfo: dynamicInfo)
            servers[serverID] = updatedServer
            return updatedServer
        }
        didUpdateLoads?(updatedServers)
    }
}

extension ServerRepository {
    /// Mock repository which partially implements functionality of the real thing.
    ///
    /// Suitable for tests where simple changes occur within the repository, or callbacks are required such as whenever
    /// servers are inserted. Unit tests should instead construct a minimal mock repository.
    ///
    /// For integration tests, it is preferable to use the live server repository based on an in-memory `AppDatabase`.
    /// This results in more coverage and easier setup,
    public static func mock(storage: MockServerStorage) -> Self {
        return .init(
            serverCount: { storage.serverCount },
            upsertServers: storage.upsert,
            server: storage.getFirstServer,
            servers: storage.getServers,
            deleteServers: storage.deleteServers,
            upsertLoads: storage.upsert
        )
    }
}

extension Domain.VPNServer {
    func with(dynamicInfo: ContinuousServerProperties) -> Domain.VPNServer {
        VPNServer(
            logical: self.logical.with(dynamicInfo: dynamicInfo),
            endpoints: self.endpoints
        )
    }
}

extension Domain.Logical {
    func with(dynamicInfo: ContinuousServerProperties) -> Domain.Logical {
        return Domain.Logical(
            id: id,
            name: name,
            domain: domain,
            load: dynamicInfo.load,
            entryCountryCode: entryCountryCode,
            exitCountryCode: exitCountryCode,
            tier: tier,
            score: dynamicInfo.score,
            status: dynamicInfo.status,
            feature: feature,
            city: city,
            hostCountry: hostCountry,
            translatedCity: translatedCity,
            latitude: latitude,
            longitude: longitude,
            gatewayName: gatewayName
        )
    }
}

#endif
