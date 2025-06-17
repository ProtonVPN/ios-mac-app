//
//  Created on 20/05/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import XCTest

@testable import ExtensionManager

final class ConnectionConfigurationTests: XCTestCase {
    func testModel() {
        let config = ConnectionConfiguration(username: "Proton VPN", wireguardConfig: .init())
        XCTAssertFalse(config.wireguardConfig.dnsServers.isEmpty)

        XCTAssertFalse(ConnectionConfigurationKey.testValue.wireguardConfig.dnsServers.isEmpty)
        XCTAssertFalse(ConnectionConfigurationKey.liveValue.wireguardConfig.dnsServers.isEmpty)
    }
}
