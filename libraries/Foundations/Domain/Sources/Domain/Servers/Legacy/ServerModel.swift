//
//  Created on 28/01/2026 by Chris Janusiewicz.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct ServerModel: Codable, Equatable {
    public let id: String
    public let name: String
    public let domain: String
    public private(set) var load: Int
    public let entryCountryCode: String // use when feature.secureCore is true
    public let exitCountryCode: String
    public let tier: Int
    public private(set) var score: Double
    public private(set) var status: Int
    public let feature: ServerFeature
    public let city: String?
    public let state: String?
    public let ips: [ServerIp]
    public var location: ServerLocation
    public let hostCountry: String?
    public let translatedCity: String?
    public let gatewayName: String?

    public init(id: String, name: String, domain: String, load: Int, entryCountryCode: String, exitCountryCode: String, tier: Int, feature: ServerFeature, city: String?, state: String?, ips: [ServerIp], score: Double, status: Int, location: ServerLocation, hostCountry: String?, translatedCity: String?, gatewayName: String?) {
        self.id = id
        self.name = name
        self.domain = domain
        self.load = load
        self.exitCountryCode = exitCountryCode
        self.entryCountryCode = entryCountryCode
        self.tier = tier
        self.feature = feature
        self.city = city
        self.state = state
        self.ips = ips
        self.score = score
        self.status = status
        self.location = location
        self.hostCountry = hostCountry
        self.translatedCity = translatedCity
        self.gatewayName = gatewayName
    }

    public static func == (lhs: ServerModel, rhs: ServerModel) -> Bool {
        lhs.name == rhs.name
    }

    public mutating func update(continuousProperties: ContinuousServerProperties) {
        load = continuousProperties.load
        score = continuousProperties.score
        status = continuousProperties.status
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case domain
        case load
        case entryCountryCode
        case exitCountryCode
        case tier
        case location
        case ips
        case score
        case status
        case feature = "features"
        case city
        case state
        case hostCountry
        case translatedCity
        case gatewayName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ips: [ServerIp] = if let decodedIPs = try? container.decode([ServerIp].self, forKey: CodingKeys.ips) {
            decodedIPs
        } else {
            []
        }

        let feature = try ServerFeature(rawValue: container.decode(Int.self, forKey: CodingKeys.feature))

        let location: ServerLocation = if let decodedLocation = try? container.decode(ServerLocation.self, forKey: CodingKeys.location) {
            decodedLocation
        } else {
            ServerLocation(lat: 0, long: 0)
        }

        try self.init(
            id: container.decode(String.self, forKey: CodingKeys.id),
            name: container.decode(String.self, forKey: CodingKeys.name),
            domain: container.decode(String.self, forKey: CodingKeys.domain),
            load: container.decode(Int.self, forKey: CodingKeys.load),
            entryCountryCode: container.decode(String.self, forKey: CodingKeys.entryCountryCode),
            exitCountryCode: container.decode(String.self, forKey: CodingKeys.exitCountryCode),
            tier: container.decode(Int.self, forKey: CodingKeys.tier),
            feature: feature,
            city: container.decodeIfPresent(String.self, forKey: CodingKeys.city),
            state: container.decodeIfPresent(String.self, forKey: CodingKeys.state),
            ips: ips,
            score: container.decode(Double.self, forKey: CodingKeys.score),
            status: container.decode(Int.self, forKey: CodingKeys.status),
            location: location,
            hostCountry: container.decodeIfPresent(String.self, forKey: CodingKeys.hostCountry),
            translatedCity: container.decodeIfPresent(String.self, forKey: CodingKeys.translatedCity),
            gatewayName: container.decodeIfPresent(String.self, forKey: CodingKeys.gatewayName)
        )
    }
}
