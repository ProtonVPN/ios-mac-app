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

    /// Limits results to servers with a tier equal to or lower than this value
    case maximumTier(Int)

    case features(ServerFeatureFilter)

    /// Protocol overrides
    case supports(protocol: ProtocolSupport)

    /// Filter by server type
    case kind(ServerTypeFilter)

    /// Filter by city name
    case city(String)

    /// Filters by substring on country code, gateway name, city or country name.
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
        case standard(country: String?)

        /// Only include gateways. Provide a string value to match only servers belonging to the gateway with that name
        case gateway(name: String?)

        /// Matches any standard server, not constrained by the country code
        public static var standard: Self { .standard(country: nil) }

        /// Matches any gateway server, not constrained by gateway name
        public static var gateway: Self { .gateway(name: nil) }
    }
}

public enum VPNServerOrder {
    case random
    case fastest
    case nameAscending
}
