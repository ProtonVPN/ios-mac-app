//
//  Created on 19/12/2024.
//
//  Copyright (c) 2024 Proton AG
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

import XCTest

import NetShield

@testable import LegacyCommon

final class NoOpVpnManagerTests: BaseConnectionTestCase {
    func testNoOpVpnManager() {
        let manager = NoOpVpnManager()

        XCTAssertEqual(manager.state, VpnState.invalid)
        manager.refreshState()
        XCTAssertEqual(manager.state, VpnState.invalid)

        XCTAssertEqual(manager.netShieldStats, NetShieldModel.zero(enabled: false))

        manager.setOnDemand(true)

        manager.isOnDemandEnabled { onDemand in
            XCTAssertFalse(onDemand)
        }

        XCTAssertNil(manager.currentVpnProtocol)
        XCTAssertNil(manager.isLocalAgentConnected)
    }
}
