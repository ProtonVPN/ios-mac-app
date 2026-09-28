//
//  Created on 14.09.2026 by Larissa Perara.
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

import Testing
import Domain
@testable import CoreConnection

@Suite("ConnectionFeatureProvider.requestedFeatures")
struct ConnectionFeatureProviderRequestedFeaturesTests {
    // Note: When we switch the MDM floor to be .advanced, this test needs to be changed to .advanced instead of standard.
    let expectedMDMFloor: KillSwitchMode = .standard
    
    @Test("Always-on is disabled that the kill switch persistence is correctly handled", arguments: KillSwitchMode.allCases)
    func alwaysOnDisabledKillSwitchPersistence(requested: KillSwitchMode) {
        #expect(ConnectionFeatureProvider.effectiveKillSwitchMode(requested: requested,
                                                                  alwaysOnEnabled: false) == requested)
    }
    
    @Test("Always-On enabled, requested kill switch mode is off.", arguments: [KillSwitchMode.off, .standard])
    func alwaysOnEnabledKillSwitchRequestedOff(requested: KillSwitchMode) {
        #expect(ConnectionFeatureProvider.effectiveKillSwitchMode(requested: requested,
                                                                  alwaysOnEnabled: true) == expectedMDMFloor)
    }
    
    // Note: Once this floor gets moved to advanced, we can mimic the test above for all cases and it should be equivalent to the expected floor.
    @Test("Always-On enabled, requested kill switch mode is advanced.")
       func alwaysOnEnabledKillSwitchRequestedAdvanced() {
           #expect(ConnectionFeatureProvider.effectiveKillSwitchMode(requested: .advanced,
                                                                     alwaysOnEnabled: true) == .advanced)
       }
    
}
