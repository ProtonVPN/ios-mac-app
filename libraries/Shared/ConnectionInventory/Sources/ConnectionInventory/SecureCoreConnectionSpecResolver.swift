//
//  Created on 15/05/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain

public enum SecureCoreConnectionSpecResolver {
    public static func fastestLocation(
        secureCoreEnabled: Bool,
        connectedExitCountryCode: String?,
        isFreeTier: Bool
    ) -> ConnectionSpec.Location {
        // Free users can only authorize `.any(.fastest)`. Pinning to a specific country
        // here would trip the intent resolver and pop the "specific country" upsell.
        // (Free tier also can't use Secure Core, so the SC branch below is unreachable for them.)
        if isFreeTier {
            return .any(.fastest)
        }

        if secureCoreEnabled {
            // Toggle-on-while-connected: target a Secure Core server exiting via the connected
            // country to preserve the user's exit location. No connected country → global fastest.
            if let countryCode = connectedExitCountryCode {
                return .secureCore(.anyHop(to: countryCode, .fastest))
            }
            return .secureCore(.any(.fastest))
        }

        if let countryCode = connectedExitCountryCode {
            return .country(code: countryCode, order: .fastest)
        }
        return .any(.fastest)
    }

    public static func fastestSpec(
        secureCoreEnabled: Bool,
        connectedExitCountryCode: String?,
        isFreeTier: Bool
    ) -> ConnectionSpec {
        .init(
            location: fastestLocation(
                secureCoreEnabled: secureCoreEnabled,
                connectedExitCountryCode: connectedExitCountryCode,
                isFreeTier: isFreeTier
            ),
            features: []
        )
    }

    public static func reconnectTrigger(
        connectedExitCountryCode: String?,
        isFreeTier: Bool
    ) -> UserInitiatedVPNChange.VPNTrigger {
        // Free users always reconnect to `.any(.fastest)` (see `fastestLocation`), so the
        // trigger is `.auto` regardless of the previously-connected country.
        if isFreeTier {
            return .auto
        }
        return connectedExitCountryCode == nil ? .auto : .country
    }
}
