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

enum SecureCoreConnectionSpecResolver {
    static func fastestLocation(
        secureCoreEnabled: Bool,
        connectedExitCountryCode: String?
    ) -> ConnectionSpec.Location {
        if secureCoreEnabled {
            // Match iOS/default quick-connect behavior:
            // secure core toggle resolves to fastest secure core, not exit-country pinning.
            return .secureCore(.any(.fastest))
        }

        if let countryCode = connectedExitCountryCode {
            return .country(code: countryCode, order: .fastest)
        }
        return .any(.fastest)
    }

    static func fastestSpec(
        secureCoreEnabled: Bool,
        connectedExitCountryCode: String?
    ) -> ConnectionSpec {
        .init(
            location: fastestLocation(
                secureCoreEnabled: secureCoreEnabled,
                connectedExitCountryCode: connectedExitCountryCode
            ),
            features: []
        )
    }

    static func reconnectTrigger(connectedExitCountryCode: String?) -> UserInitiatedVPNChange.VPNTrigger {
        connectedExitCountryCode == nil ? .auto : .country
    }
}
