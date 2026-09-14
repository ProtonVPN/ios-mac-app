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
import Strings

public enum SecureCoreConnectionSpecResolver {
    public static func fastestLocation(
        secureCoreEnabled: Bool,
        connectedExitCountryCode: String?,
        isFree: Bool
    ) -> ConnectionSpec.Location {
        // Free users can only authorize `.any(.fastest)`. Pinning to a specific country
        // here would trip the intent resolver and pop the "specific country" upsell.
        // (Free tier also can't use Secure Core, so the SC branch below is unreachable for them.)
        if isFree {
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
        isFree: Bool
    ) -> ConnectionSpec {
        .init(
            location: fastestLocation(
                secureCoreEnabled: secureCoreEnabled,
                connectedExitCountryCode: connectedExitCountryCode,
                isFree: isFree
            ),
            features: []
        )
    }

    /// ConnectionSpec to use when toggling SC and connected.
    ///
    /// ```
    /// switch (isFree, secureCoreEnabled, exitCountryCode) {
    /// case (true, _, _):
    ///     return .any(.fastest) // upsell
    /// case (false, true, .some(let country)):
    ///     return .secureCore(.anyHop(to: country, .fastest)) // fastest Secure Core exiting via `country`
    /// case (false, true, nil):
    ///     return .secureCore(.any(.fastest)) // global fastest Secure Core
    /// case (false, false, .some(let country)):
    ///     return .country(code: country, order: .random) // random standard server in `country`
    /// case (false, false, nil):
    ///     return .any(.random) // any random server
    /// }
    /// ```
    public static func toggleReconnectLocation(
        secureCoreEnabled: Bool,
        exitCountryCode: String?,
        isFree: Bool
    ) -> ConnectionSpec.Location {
        if isFree {
            return .any(.fastest)
        }

        if let exitCountryCode {
            return secureCoreEnabled
                ? .secureCore(.anyHop(to: exitCountryCode, .fastest))
                : .country(code: exitCountryCode, order: .random)
        }
        return secureCoreEnabled ? .secureCore(.any(.fastest)) : .any(.random)
    }

    public static func toggleReconnectSpec(
        secureCoreEnabled: Bool,
        exitCountryCode: String?,
        isFree: Bool
    ) -> ConnectionSpec {
        .init(
            location: toggleReconnectLocation(
                secureCoreEnabled: secureCoreEnabled,
                exitCountryCode: exitCountryCode,
                isFree: isFree
            ),
            features: []
        )
    }

    /// Text for the Secure Core toggle disconnect/reconnect warning.
    ///
    /// ```
    /// switch (turningOn, fallbackCountryName) {
    /// case (false, _):
    ///     return "Toggling Secure Core will end your current connection."
    /// case (true, nil):
    ///     return "Turning on Secure Core ... try to reconnect to the same country."
    /// case (true, .some(let country)):
    ///     return "Secure Core isn't available in \(country). Your VPN will reconnect "
    ///          + "through the fastest available Secure Core server."
    /// }
    /// ```
    public static func toggleAlertMessage(
        turningOn: Bool,
        fallbackCountryName: String?
    ) -> String {
        if !turningOn {
            return Localizable.viewToggleWillCauseDisconnect
        }
        if let countryName = fallbackCountryName {
            return Localizable.viewToggleOnReconnectFastestFallback(countryName)
        }
        return Localizable.viewToggleOnReconnectSameCountry
    }

    public static func reconnectTrigger(
        connectedExitCountryCode: String?,
        isFree: Bool
    ) -> UserInitiatedVPNChange.VPNTrigger {
        // Free users always reconnect to `.any(.fastest)` (see `fastestLocation`), so the
        // trigger is `.auto` regardless of the previously-connected country.
        if isFree {
            return .auto
        }
        return connectedExitCountryCode == nil ? .auto : .country
    }
}
