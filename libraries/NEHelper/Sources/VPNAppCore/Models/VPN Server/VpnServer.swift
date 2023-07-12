//
//  Created on 2023-07-05.
//
//  Copyright (c) 2023 Proton AG
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

/// This is a struct version of `ServerModel` object from `vpncore`. It was created to not move
/// whole old NSObject with all the old code into a refactored app.
///
/// There is also one difference: it doesn't contain the list of ServerIP's.
///
/// The plan is to get rid of `ServerModel` whenever possible and move to using this struct only.
public struct VpnServer: Codable, Equatable {
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
    public let hostCountry: String?
    public let translatedCity: String?

    public init(id: String, name: String, domain: String, load: Int, entryCountryCode: String, exitCountryCode: String, tier: Int, score: Double, status: Int, feature: ServerFeature, city: String?, hostCountry: String?, translatedCity: String?) {
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
    }

    public var isVirtual: Bool {
        if let hostCountry = hostCountry, !hostCountry.isEmpty {
            return true
        }
        return false
    }
}
