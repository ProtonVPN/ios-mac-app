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
import VPNAppCore

/// UI presents servers grouped by either a country or a "gateway"
public class ServerGroup: Equatable {
    public var kind: Kind
    public var servers: [ServerModel]
    public var feature: ServerFeature

    public lazy var lowestTier: Int = {
        switch kind {
        case .country:
            return servers.reduce(into: Int.max) { minTier, server in
                if server.tier < minTier {
                    minTier = server.tier
                }
            }
        case .gateway:
            return CoreAppConstants.VpnTiers.plus
        }
    }()

    public init(kind: Kind, servers: [ServerModel], feature: ServerFeature = .zero) {
        self.kind = kind
        self.servers = servers
        self.feature = feature
    }

    public enum Kind: Equatable, Hashable {
        case country(CountryModel)
        case gateway(String)
    }

    public static func == (lhs: ServerGroup, rhs: ServerGroup) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.servers == rhs.servers &&
        lhs.feature == rhs.feature
    }
}
