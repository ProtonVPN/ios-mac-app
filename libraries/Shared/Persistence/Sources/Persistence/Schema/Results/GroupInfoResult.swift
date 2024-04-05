//
//  Created on 15/01/2024.
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

import GRDB

import Domain

/// Holds information about a server grouping (by country or gateway)
struct GroupInfoResult: Decodable, FetchableRecord {
    let exitCountryCode: String
    let gatewayName: String?
    let featureIntersection: ServerFeature // Features provided by all servers
    let featureUnion: ServerFeature // All features provided by at least one server
    let minTier: Int
    let maxTier: Int
    let serverCount: Int
    let cityCount: Int
    let latitude: Double
    let longitude: Double

    let isVirtual: Int // Union of (logical.hostCountry != nil && logical.hostCountry != logical.entryCountryCode)
    let statusUnion: Int // Union of (server.status && logical.status)
    let protocolSupport: ProtocolSupport // Union of protocols supported by servers
}
