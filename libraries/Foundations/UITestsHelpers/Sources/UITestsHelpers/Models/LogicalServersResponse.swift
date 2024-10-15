//
//  Created on 8/10/24.
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

// Models for /vpn/logicals
public struct LogicalServersResponse: Codable {
    let code: Int
    let logicalServers: [LogicalServer]
    
    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case logicalServers = "LogicalServers"
    }
}

public struct LogicalServer: Codable {
    let name: String
    let entryCountry: String
    let exitCountry: String
    let domain: String
    let tier: Int
    let features: Int
    let region: String?
    let city: String?
    let score: Double
    let hostCountry: String?
    let id: String
    let location: Location
    let status: Int
    let servers: [Server]
    let load: Int
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case entryCountry = "EntryCountry"
        case exitCountry = "ExitCountry"
        case domain = "Domain"
        case tier = "Tier"
        case features = "Features"
        case region = "Region"
        case city = "City"
        case score = "Score"
        case hostCountry = "HostCountry"
        case id = "ID"
        case location = "Location"
        case status = "Status"
        case servers = "Servers"
        case load = "Load"
    }
}

public struct Location: Codable {
    let lat: Double
    let long: Double
    
    enum CodingKeys: String, CodingKey {
        case lat = "Lat"
        case long = "Long"
    }
}

public struct Server: Codable {
    let entryIP: String
    let exitIP: String
    let domain: String
    let id: String
    let label: String
    let x25519PublicKey: String
    let generation: Int
    let status: Int
    let servicesDown: Int
    let servicesDownReason: String?
    
    enum CodingKeys: String, CodingKey {
        case entryIP = "EntryIP"
        case exitIP = "ExitIP"
        case domain = "Domain"
        case id = "ID"
        case label = "Label"
        case x25519PublicKey = "X25519PublicKey"
        case generation = "Generation"
        case status = "Status"
        case servicesDown = "ServicesDown"
        case servicesDownReason = "ServicesDownReason"
    }
}
