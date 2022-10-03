//
//  Created on 2022-10-03.
//
//  Copyright (c) 2022 Proton AG
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

class ServerStatusRequest: APIRequest {
    let params: Params
    let httpMethod = "GET"
    let hasBody = false

    var endpointUrl: String { "vpn/servers/\(params.serverId)?WithReconnectAlternative" }

    struct Params: Codable {
        let serverId: String
    }

    struct Server: Codable {
        let entryIp: String
        let exitIp: String
        let domain: String
        let id: String
        let status: Int

        enum CodingKeys: String, CodingKey {
            case entryIp = "EntryIP"
            case exitIp = "ExitIP"
            case domain = "Domain"
            case id = "ID"
            case status = "Status"
        }
    }

    class Response: Codable {
        let server: Server
        let reconnectTo: Server?

        enum CodingKeys: String, CodingKey {
            case reconnectTo = "ReconnectTo"
        }

        func encode(to encoder: Encoder) throws {
            try server.encode(to: encoder)

            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(reconnectTo, forKey: .reconnectTo)
        }

        required init(from decoder: Decoder) throws {
            self.server = try Server(from: decoder)

            do {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.reconnectTo = try container.decode(Server?.self, forKey: .reconnectTo)
            } catch {
                log.error("Could not decode ReconnectTo response: \(error)", category: .connection)
                self.reconnectTo = nil
            }
        }
    }

    public init(params: Params) {
        self.params = params
    }
}
