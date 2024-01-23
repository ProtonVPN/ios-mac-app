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

public class MockServerStorage {

    public var servers: [String: VPNServer]

    public var didStoreServers: (([VPNServer]) -> Void)?
    public var didUpdateLoads: (([VPNServer]) -> Void)?

    public init(servers: [VPNServer] = []) {
        self.servers = servers.reduce(into: [:]) { result, server in
            result[server.logical.id] = server
        }
    }
}

extension ServerRepository {
    public static func mock(storage: MockServerStorage) -> Self {
        return .init(
            serverCount: { storage.servers.count },
            upsertServers: { servers in
                servers.forEach { storage.servers[$0.id] = $0 }
                storage.didStoreServers?(servers)
            },
            server: { filters, _ in
                return filters.reduce(Array(storage.servers.values)) { servers, filter in
                    switch filter {
                    case .logicalID(let id):
                        return servers.filter { $0.logical.id == id }
                    default:
                        XCTFail("Unimplemented server filter: \(filter)")
                        return servers
                    }
                }.first
            },
            servers: { filters, _ in
                return filters.reduce(Array(storage.servers.values)) { servers, filter in
                    switch filter {
                    case .logicalID(let id):
                        return servers.filter { $0.logical.id == id }
                    default:
                        XCTFail("Unimplemented server filter: \(filter)")
                        return servers
                    }
                }.map { ServerInfo(logical: $0.logical, protocolSupport: $0.supportedProtocols)}
            },
            upsertLoads: { loads in
                let updatedServers: [VPNServer] = loads.compactMap { dynamicInfo in
                    let serverID = dynamicInfo.serverId
                    guard let server = storage.servers[serverID] else {
                        XCTFail("Failed to update dynamic info - no server with ID \(serverID)")
                        return nil
                    }
                    let updatedServer = server.with(dynamicInfo: dynamicInfo)
                    storage.servers[serverID] = updatedServer
                    return updatedServer
                }
                storage.didUpdateLoads?(updatedServers)
            }
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
            latitude: longitude,
            longitude: latitude,
            gatewayName: gatewayName
        )
    }
}

#endif
