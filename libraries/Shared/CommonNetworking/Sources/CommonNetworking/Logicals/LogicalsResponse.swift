//
//  Created on 23/05/2024.
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

enum LogicalsResponse: Decodable {
    /// Servers the app can use. Never empty.
    case servers([LogicalDTO])

    /// The response listed servers and not one of them could be read, so the payload has changed shape.
    case unreadable(receivedServerCount: Int)

    /// The response listed no servers at all.
    case empty

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let (servers, receivedCount) = try Self.decodeServers(from: container)

        if !servers.isEmpty {
            self = .servers(servers)
        } else if receivedCount > 0 {
            self = .unreadable(receivedServerCount: receivedCount)
        } else {
            self = .empty
        }
    }

    /// Reads the server list, keeping every server it can and counting everything the response listed.
    private static func decodeServers(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> (servers: [LogicalDTO], receivedCount: Int) {
        do {
            // Fast path: the array is fully valid
            let servers = try container.decode([LogicalDTO].self, forKey: .logicalServers)
            return (servers, servers.count)
        } catch {
            // At least one element is bad. Read them one at a time so that the rest survive.
            log.error(
                "Failed to parse server list, manually parsing one by one",
                category: .api,
                event: .response,
                metadata: ["error": "\(error)"]
            )
            var elements = try container.nestedUnkeyedContainer(forKey: .logicalServers)
            var servers: [LogicalDTO] = []
            var receivedCount = 0
            while !elements.isAtEnd {
                let elementDecoder = try elements.superDecoder()
                receivedCount += 1
                if let server = try? LogicalDTO(from: elementDecoder) {
                    servers.append(server)
                }
            }
            return (servers, receivedCount)
        }
    }

    enum CodingKeys: String, CodingKey {
        case logicalServers
    }
}
