//
//  Created on 18/12/2023.
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

import GRDB

import Domain

/// Contains static information about a logical server.
struct Logical: Codable {
    let id: String
    let name: String
    let domain: String
    let entryCountryCode: String
    let exitCountryCode: String
    let tier: Int
    let feature: ServerFeature
    let city: String?
    let hostCountry: String?
    let translatedCity: String?
    let longitude: Double
    let latitude: Double
    let gatewayName: String?
}
