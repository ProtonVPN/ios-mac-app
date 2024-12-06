//
//  Created on 28/11/2024.
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

import Domain
import Dependencies
import DependenciesMacros
import Persistence

import Connection

@DependencyClient
struct ServerSelector: Sendable {
    enum SelectionError: Error {
        case noLogical
        case noEndpoints
    }

    var select: @Sendable (_ spec: ConnectionSpec) throws -> Server
}

extension ServerSelector: DependencyKey {
    static let liveValue = ServerSelector { spec in
        @Dependency(\.serverRepository) var repository

        // TODO: VPNAPPL-2502, Server selection based on `ConnectionSpec`
        let server = repository.getFirstServer(filteredBy: [], orderedBy: .random)

        guard let server else {
            throw SelectionError.noLogical
        }

        guard let endpoint = server.endpoints.randomElement() else {
            throw SelectionError.noEndpoints
        }

        return Server(logical: server.logical, endpoint: endpoint)
    }
}

extension DependencyValues {
    var serverSelector: ServerSelector {
        get { self[ServerSelector.self] }
        set { self[ServerSelector.self] = newValue }
    }
}

extension ServerIdentifier: DependencyKey {
    public static let liveValue: ServerIdentifier = .init(
        fullServerInfo: { logicalServerInfo in
            @Dependency(\.serverRepository) var repository
            let idFilter = VPNServerFilter.logicalID(logicalServerInfo.logicalID)
            guard let server = repository.getFirstServer(filteredBy: [idFilter], orderedBy: .none) else {
                fatalError()
            }
            guard let endpoint = server.endpoints[id: logicalServerInfo.serverID] else {
                log.debug(
                    "Unable to identify server - missing endpoint",
                    category: .persistence,
                    metadata: [
                        "logicalID": "\(logicalServerInfo.logicalID)",
                        "serverID": "\(logicalServerInfo.serverID)"
                    ]
                )
                return nil
            }
            return Server(logical: server.logical, endpoint: endpoint)
        }
    )
}

extension Collection where Element: Identifiable {
    subscript(id elementID: Element.ID) -> Element? {
        return first { $0.id == elementID }
    }
}
