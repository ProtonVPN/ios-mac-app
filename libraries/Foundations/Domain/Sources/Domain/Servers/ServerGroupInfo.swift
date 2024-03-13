//
//  Created on 2023-07-31.
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
import CoreLocation

public struct ServerGroupInfo {

    public let kind: Kind
    public let featureIntersection: ServerFeature // Features provided by all servers
    public let featureUnion: ServerFeature // All features provided by at least one server
    public let minTier: Int
    public let maxTier: Int
    public let cityCount: Int
    public let serverCount: Int
    public let latitude: Double
    public let longitude: Double

    public let supportsSmartRouting: Bool
    public let isUnderMaintenance: Bool
    public let protocolSupport: ProtocolSupport

    public enum Kind: Equatable, Hashable {
        case country(code: String)
        case gateway(name: String)
    }

    public init(
        kind: Kind,
        featureIntersection: ServerFeature,
        featureUnion: ServerFeature,
        minTier: Int,
        maxTier: Int,
        serverCount: Int,
        cityCount: Int,
        latitude: Double,
        longitude: Double,
        supportsSmartRouting: Bool,
        isUnderMaintenance: Bool,
        protocolSupport: ProtocolSupport
    ) {
        self.kind = kind
        self.featureIntersection = featureIntersection
        self.featureUnion = featureUnion
        self.minTier = minTier
        self.maxTier = maxTier
        self.serverCount = serverCount
        self.cityCount = cityCount
        self.latitude = latitude
        self.longitude = longitude
        self.isUnderMaintenance = isUnderMaintenance
        self.supportsSmartRouting = supportsSmartRouting
        self.protocolSupport = protocolSupport
    }

    public var location: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
