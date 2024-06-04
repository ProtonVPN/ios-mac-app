//
//  Created on 24/05/2024.
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

struct LogicalDTO: Codable {
    public let id: String
    public let name: String
    public let domain: String
    public let load: Int
    public let entryCountry: String // use when feature.secureCore is true
    public let exitCountry: String
    public let tier: Int
    public private(set) var score: Double
    public private(set) var status: Int
    public let features: ServerFeature // features?
    public let city: String?
    public let servers: [ServerIpDTO]
    public var location: LogicalLocationDTO
    public let hostCountry: String?
    public let translatedCity: String?
    public let gatewayName: String?


    /// We must provide CodingKeys to decode ID, since `JSONDecoder.decapitalisingFirstLetter` does not modify keys
    /// that have a capital prefix length longer than 1 character.
    public enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case domain
        case load
        case entryCountry
        case exitCountry
        case tier
        case location
        case servers
        case score
        case status
        case features
        case city
        case hostCountry
        case translatedCity
        case gatewayName
    }
}
