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

public struct ServerModel: Codable {
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

    public mutating func update(continuousProperties: ContinuousServerProperties) {
        load = continuousProperties.load
        score = continuousProperties.score
        status = continuousProperties.status
    }
}
