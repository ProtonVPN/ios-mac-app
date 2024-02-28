//
//  Created on 12/01/2024.
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

// TODO: VPNAPPL-2100 Domain model refinement
public struct Logical: Codable, Equatable {

    public let id: String
    public let name: String
    public let domain: String
    public let load: Int
    public let entryCountryCode: String // use when feature.secureCore is true
    public let exitCountryCode: String
    public let tier: Int
    public let score: Double
    public let status: Int
    public let feature: ServerFeature
    public let city: String?
    public let hostCountry: String?
    public let translatedCity: String?
    public let latitude: Double
    public let longitude: Double
    public let gatewayName: String?

    public init(
        id: String,
        name: String,
        domain: String,
        load: Int,
        entryCountryCode: String,
        exitCountryCode: String,
        tier: Int,
        score: Double,
        status: Int,
        feature: ServerFeature,
        city: String?,
        hostCountry: String?,
        translatedCity: String?,
        latitude: Double,
        longitude: Double,
        gatewayName: String?
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.load = load
        self.entryCountryCode = entryCountryCode
        self.exitCountryCode = exitCountryCode
        self.tier = tier
        self.score = score
        self.status = status
        self.feature = feature
        self.city = city
        self.hostCountry = hostCountry
        self.translatedCity = translatedCity
        self.latitude = latitude
        self.longitude = longitude
        self.gatewayName = gatewayName
    }

    public var isVirtual: Bool {
        if let hostCountry = hostCountry, !hostCountry.isEmpty {
            return true
        }
        return false
    }
}
