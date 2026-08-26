//
//  Created on 25/08/2026 by Max Kupetskyi.
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
import Testing
@testable import VPNAppCore
@testable import VPNShared
import VPNSharedTesting

@Suite("Plan change")
struct PlanChangeTests {
    /// The pair the keychain posts when it notices the plan changed.
    private func downgradeInfo(from: (String, VpnTier), to: (String, VpnTier)) -> VpnDowngradeInfo {
        (
            from: VpnKeychainMock.vpnCredentials(planName: from.0, maxTier: from.1),
            to: VpnKeychainMock.vpnCredentials(planName: to.0, maxTier: to.1)
        )
    }

    @Test("An upgrade carries both tiers and the name of the plan the user moved to")
    func upgradeCarriesTheNewPlan() {
        let change = PlanChange(downgradeInfo(from: ("free", .free), to: ("vpnplus", .paid)))

        #expect(change.oldTier == .free)
        #expect(change.newTier == .paid)
        #expect(change.newPlanName == "vpnplus")
        #expect(change.isUpgrade)
    }

    @Test("A downgrade is not an upgrade")
    func downgradeIsNotAnUpgrade() {
        let change = PlanChange(downgradeInfo(from: ("vpnplus", .paid), to: ("free", .free)))

        #expect(change.oldTier == .paid)
        #expect(change.newTier == .free)
        #expect(change.newPlanName == "free")
        #expect(!change.isUpgrade)
    }

    @Test("A change that stays in the same tier is not an upgrade either")
    func sameTierIsNotAnUpgrade() {
        let change = PlanChange(downgradeInfo(from: ("vpnplus", .paid), to: ("bundle2022", .paid)))

        #expect(change.newPlanName == "bundle2022")
        #expect(!change.isUpgrade)
    }
}
