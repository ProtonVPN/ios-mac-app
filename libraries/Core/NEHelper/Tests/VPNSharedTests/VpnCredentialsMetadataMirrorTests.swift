//
//  Created on 10/07/2026 by Max Kupetskyi.
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

import Sharing
import Testing
@testable import VPNShared

@Suite(.serialized)
struct VpnCredentialsMetadataMirrorTests {
    @Test
    func projectsOnlySuccessfullyStoredCredentialsAndClearsThem() {
        @Shared(.userTier) var userTier
        @Shared(.userPlan) var userPlan
        let originalTier = userTier
        let originalPlan = userPlan
        defer {
            $userTier.withLock { $0 = originalTier }
            $userPlan.withLock { $0 = originalPlan }
        }

        $userTier.withLock { $0 = .internalTier }
        $userPlan.withLock { $0 = "internal" }
        VpnCredentialsMetadataMirror.update(
            afterStoring: VpnKeychainMock.vpnCredentials(
                planName: "free",
                maxTier: .freeTier
            ),
            succeeded: false
        )
        #expect(userTier == .internalTier)
        #expect(userPlan == "internal")

        VpnCredentialsMetadataMirror.update(
            afterStoring: VpnKeychainMock.vpnCredentials(
                planName: "plus",
                maxTier: .paidTier
            ),
            succeeded: true
        )
        #expect(userTier == .paidTier)
        #expect(userPlan == "plus")

        VpnCredentialsMetadataMirror.clear()
        #expect(userTier == nil)
        #expect(userPlan == nil)
    }
}
