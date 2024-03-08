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

import Domain
import VPNAppCore

/// UI presents servers grouped by either a country or a "gateway"
public struct ServerGroup: Equatable {
    public var kind: Kind
    public var servers: [ServerModel]
    public var feature: ServerFeature

    public init(kind: Kind, servers: [ServerModel], feature: ServerFeature = .zero) {
        self.kind = kind
        self.servers = servers
        self.feature = feature
    }

    public enum Kind: Equatable, Hashable {
        case country(CountryModel)
        case gateway(String)

        public var lowestTier: Int {
            switch self {
            case .country(let countryModel):
                return countryModel.lowestTier
            case .gateway:
                return .paidTier
            }
        }
    }

    public static func == (lhs: ServerGroup, rhs: ServerGroup) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.servers == rhs.servers &&
        lhs.feature == rhs.feature
    }
}
