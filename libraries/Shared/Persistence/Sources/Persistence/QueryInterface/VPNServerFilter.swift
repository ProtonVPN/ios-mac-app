//
//  Created on 21/12/2023.
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

/// Defines implementation agnostic filtering methods
public enum VPNServerFilter {

    /// Filter by logical ID
    case logicalID(String)

    /// Filter results by servers tier
    case tier(ServerTierFilter)

    case features(ServerFeatureFilter)

    case isNotUnderMaintenance

    /// Protocol overrides
    case supports(protocol: ProtocolSupport)

    /// Filter by server type
    case kind(ServerTypeFilter)

    /// Filter by city name
    case city(String)

    /// Text search filter - filters by country code, or substring of gateway name, city or localized country name
    case matches(String)

    public struct ServerFeatureFilter {
        /// Limits results to servers that provide at least these features
        let required: ServerFeature

        /// Exclude servers that support these features
        let excluded: ServerFeature

        public static var standard: Self {
            return .init(required: .zero, excluded: .secureCore)
        }

        public static var secureCore: Self {
            return .init(required: .secureCore, excluded: .zero)
        }

        public static func standard(
            with additionalFeatures: ServerFeature = .zero,
            without excludedFeatures: ServerFeature = .zero
        ) -> Self {
            return .init(required: additionalFeatures, excluded: .secureCore.union(excludedFeatures))
        }

        public init(required: ServerFeature, excluded: ServerFeature) {
            assert(required.isDisjoint(with: excluded))
            self.required = required
            self.excluded = excluded
        }
    }

    public enum ServerTypeFilter {

        /// Filter out gateways. Provide a string value to match only servers with the specified exitCountryCode
        case country(code: String?)

        /// Only include gateways. Provide a string value to match only servers belonging to the gateway with that name
        case gateway(name: String?)

        /// Matches any standard server, not constrained by the country code
        public static var country: Self { .country(code: nil) }

        /// Matches any gateway server, not constrained by gateway name
        public static var gateway: Self { .gateway(name: nil) }
    }

    public enum ServerTierFilter {

        /// Only servers with this exact tier value
        case exact(tier: Int)

        /// Servers with tier equal to or lower than given value
        case max(tier: Int)
    }
}

public enum VPNServerOrder {
    /// Undefined ordering
    case none

    /// Randomised ordering - incurs performance penalty
    case random

    /// Server score ascending
    case fastest

    /// See `Logical.namePrefix` and `Logical.sequenceNumber` obtained from `VPNServer.splitName`
    case nameAscending
}

extension ServerGroupInfo.Kind {

    /// Convert Kind of server group into a filter for repository
    public var serverTypeFilter: VPNServerFilter.ServerTypeFilter {
        switch self {
        case .country(let code):
            return .country(code: code)
        case .gateway(let name):
            return .gateway(name: name)
        }
    }
}

public enum VPNServerGroupOrder {
    /// Sorted by gateways first, then by exit country code
    case exitCountryCodeAscending

    /// Sorted by gateways first, then by localized country name (from the exit country code), ascending
    case localizedCountryNameAscending
}
