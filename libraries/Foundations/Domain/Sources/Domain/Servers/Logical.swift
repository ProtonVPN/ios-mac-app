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

import Strings

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

    // TODO: Domain model refinement
    // Since we are no longer bound by limitations of the API representation, we could use enums to model some of
    // these properties more ergonomically. E.g. leave common properties as they are, and defines a logical type enum:
    // ```
    // enum LogicalType {
    //     gateway(name: String, exitCountryCode: String)
    //     secureCore(exitCountryCode: String, entryCountryCode: String)
    //     standard(entryCountryCode: String)
    // }
    // ```
    //
    // Additionally, enums could be used for fields such as status (e.g. `case maintenance`, `case normal`)

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
        self.longitude = longitude
        self.latitude = latitude
        self.gatewayName = gatewayName
    }

    public var isVirtual: Bool {
        if let hostCountry = hostCountry, !hostCountry.isEmpty {
            return true
        }
        return false
    }
}

/// This logic depends on both Domain and Strings.
/// Should it live in Domain, Strings, or a Shared package in the layer above this one?
extension Logical {
    public var entryCountry: String {
        return LocalizationUtility.default.countryName(forCode: entryCountryCode) ?? ""
    }

    public var exitCountry: String {
        return LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }

    public var country: String {
        return LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }
}
