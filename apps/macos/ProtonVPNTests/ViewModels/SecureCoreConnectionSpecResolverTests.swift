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

import ConnectionInventory
import Domain
@testable import ProtonVPN
import Testing

struct SecureCoreConnectionSpecResolverTests {
    @Test
    func fastestSpecUsesSecureCoreWhenEnabled() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: true,
            connectedExitCountryCode: nil,
            isFreeTier: false
        )

        #expect(spec.location == .secureCore(.any(.fastest)))
    }

    @Test
    func fastestSpecPinsToConnectedCountryWhenSecureCoreEnabledForPaidUser() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: true,
            connectedExitCountryCode: "CH",
            isFreeTier: false
        )

        #expect(spec.location == .secureCore(.anyHop(to: "CH", .fastest)))
    }

    @Test
    func fastestSpecUsesStandardCountryWhenSecureCoreDisabled() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: false,
            connectedExitCountryCode: "US",
            isFreeTier: false
        )

        #expect(spec.location == .country(code: "US", order: .fastest))
    }

    @Test
    func fastestSpecFallsBackToAnyFastestForFreeTierEvenWithConnectedCountry() {
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: false,
            connectedExitCountryCode: "US",
            isFreeTier: true
        )

        #expect(spec.location == .any(.fastest))
    }

    @Test
    func fastestSpecFallsBackToAnyFastestForFreeTierEvenWithSecureCoreEnabled() {
        // Free tier can't authorize Secure Core or country pinning, so the resolver
        // short-circuits to `.any(.fastest)` regardless of the SC toggle.
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: true,
            connectedExitCountryCode: "US",
            isFreeTier: true
        )

        #expect(spec.location == .any(.fastest))
    }

    @Test
    func reconnectTriggerUsesCountryWhenConnectedCountryExistsForPaidUser() {
        #expect(
            SecureCoreConnectionSpecResolver.reconnectTrigger(
                connectedExitCountryCode: "US",
                isFreeTier: false
            )
                == UserInitiatedVPNChange.VPNTrigger.country
        )
    }

    @Test
    func reconnectTriggerUsesAutoWhenConnectedCountryMissing() {
        #expect(
            SecureCoreConnectionSpecResolver.reconnectTrigger(
                connectedExitCountryCode: nil,
                isFreeTier: false
            )
                == UserInitiatedVPNChange.VPNTrigger.auto
        )
    }

    @Test
    func reconnectTriggerUsesAutoForFreeTierEvenWithConnectedCountry() {
        #expect(
            SecureCoreConnectionSpecResolver.reconnectTrigger(
                connectedExitCountryCode: "US",
                isFreeTier: true
            )
                == UserInitiatedVPNChange.VPNTrigger.auto
        )
    }
}
