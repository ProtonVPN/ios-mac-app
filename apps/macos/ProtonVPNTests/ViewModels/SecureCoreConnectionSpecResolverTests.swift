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
@testable import ProtonVPN
import Testing

struct SecureCoreConnectionSpecResolverTests {
    @Test
    func fastestSpecUsesSecureCoreWhenEnabled() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: true,
            connectedExitCountryCode: nil
        )

        #expect(spec.location == .secureCore(.any(.fastest)))
    }

    @Test
    func fastestSpecUsesSecureCoreFastestWhenEnabledAndCountryIsKnown() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: true,
            connectedExitCountryCode: "CH"
        )

        #expect(spec.location == .secureCore(.any(.fastest)))
    }

    @Test
    func fastestSpecUsesStandardCountryWhenSecureCoreDisabled() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: false,
            connectedExitCountryCode: "US"
        )

        #expect(spec.location == .country(code: "US", order: .fastest))
    }

    @Test
    func reconnectTriggerUsesCountryWhenConnectedCountryExists() {
        #expect(
            SecureCoreConnectionSpecResolver.reconnectTrigger(connectedExitCountryCode: "US")
                == UserInitiatedVPNChange.VPNTrigger.country
        )
    }

    @Test
    func reconnectTriggerUsesAutoWhenConnectedCountryMissing() {
        #expect(
            SecureCoreConnectionSpecResolver.reconnectTrigger(connectedExitCountryCode: nil)
                == UserInitiatedVPNChange.VPNTrigger.auto
        )
    }
}
