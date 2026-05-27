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

    /// Location to use when the user toggles Secure Core mid-connection.
    ///
    /// Asymmetric by direction (matches the iOS/macOS unified UX):
    /// - Turning **on**  + a non-nil `exitCountryCode` → fastest Secure Core exiting via that
    ///   country. Nil → global fastest SC.
    /// - Turning **off** + a non-nil `exitCountryCode` → random standard server in that country.
    ///   Nil → any random server.
    /// - Free tier: always `.any(.fastest)` (Secure Core unreachable, country-pinning would trip
    ///   the upsell).
    ///
    /// **The caller is responsible for verifying server availability** in the requested mode +
    /// exit country and passing `nil` if none exists. Use `ServerRepository.hasServer(secureCore:
    /// exitCountryCode:)` for that check. Keeping the check at the call site is what lets this
    /// module stay free of any Persistence dependency.
    public static func toggleReconnectLocation(
        secureCoreEnabled: Bool,
        exitCountryCode: String?,
        isFreeTier: Bool
    ) -> ConnectionSpec.Location {
        if isFreeTier { return .any(.fastest) }

        if secureCoreEnabled {
            return exitCountryCode.map { .secureCore(.anyHop(to: $0, .fastest)) } ?? .secureCore(.any(.fastest))
        }
        return exitCountryCode.map { .country(code: $0, order: .random) } ?? .any(.random)
    }

    public static func toggleReconnectSpec(
        secureCoreEnabled: Bool,
        exitCountryCode: String?,
        isFreeTier: Bool
    ) -> ConnectionSpec {
        .init(
            location: toggleReconnectLocation(
                secureCoreEnabled: secureCoreEnabled,
                exitCountryCode: exitCountryCode,
                isFreeTier: isFreeTier
            ),
            features: []
        )
    }

    /// Random-server location respecting the Secure Core toggle. Used by change-server flows
    /// where the user has explicitly asked for a new random server while connected. Both platforms
    /// previously used `ProfileConstants.randomProfile(.unspecified) → ConnectionSpec` which
    /// silently dropped Secure Core; this helper preserves the toggle.
    public static func randomLocation(secureCoreEnabled: Bool) -> ConnectionSpec.Location {
        secureCoreEnabled ? .secureCore(.any(.random)) : .any(.random)
    }

    public static func randomSpec(secureCoreEnabled: Bool) -> ConnectionSpec {
        .init(location: randomLocation(secureCoreEnabled: secureCoreEnabled), features: [])
    }

    /// User-facing body text for the Secure Core toggle disconnect/reconnect warning and for the
    /// "will reconnect" notice on the discourage screen. Shape:
    /// - Turning **off** → "Toggling Secure Core will end your current connection." (the base copy
    ///   used by both alert and warning when SC is being disabled).
    /// - Turning **on**  + `fallbackCountryName == nil` (SC server exists in connected country, or
    ///   user not connected) → "Turning on Secure Core ... try to reconnect to the same country."
    /// - Turning **on**  + `fallbackCountryName != nil` (no SC server in connected country) →
    ///   "Secure Core isn't available in <country>. Your VPN will reconnect through the fastest
    ///   available Secure Core server."
    ///
    /// Callers compute `fallbackCountryName` from `ServerRepository.hasServer(...)` +
    /// `LocalizationUtility.countryName(forCode:)`. Nil-out when the fallback case doesn't apply
    /// (turning off, not connected, or SC available in the connected country).
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
