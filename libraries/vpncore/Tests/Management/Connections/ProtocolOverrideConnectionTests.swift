//
//  Created on 2022-11-22.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation

/// - Note: To be implemented with remainder of protocol overrides feature.
class ProtocolOverrideConnectionTests: ConnectionTestCaseDriver {
    override func setUp() {
        let testData = MockTestData()

        container.networkingDelegate.apiServerList = [testData.server1, testData.server3, testData.server4, testData.server5]
    }

    #if false
    func testConnectingWithIpOverride() {

    }

    func testConnectingWithIpAndPortOverride() {

    }

    func testExclusiveOverrideWithNoSpecifiedPort() {

    }

    func testExclusiveOverrideWithSpecifiedPorts() {

    }

    func testSpecifiedBehaviorWithSmartProtocol() {

    }

    func testExclusiveServerSwitchingDueToMaintenance() {

    }
    #endif
}
