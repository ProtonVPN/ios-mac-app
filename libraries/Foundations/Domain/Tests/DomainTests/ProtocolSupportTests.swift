//
//  Created on 2024-01-23.
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
@testable import Domain

final class ProtocolSupportTests: XCTestCase {

    func testConversionFromVpnProtocolToProtocolSupport() throws {
        // Test empty, full and few variations
        XCTAssertEqual(ProtocolSupport(vpnProtocols: []), ProtocolSupport.zero)
        XCTAssertEqual(ProtocolSupport(vpnProtocols: [
            .ike,
            .wireGuard(.tcp),
            .wireGuard(.tls),
            .wireGuard(.udp),
        ]), ProtocolSupport.all)

        XCTAssertEqual(
            ProtocolSupport(vpnProtocols: [.ike]),
            ProtocolSupport([.ikev2])
        )
        XCTAssertEqual(
            ProtocolSupport(vpnProtocols: [.wireGuard(.tcp)]),
            ProtocolSupport([.wireGuardTCP])
        )
        XCTAssertEqual(
            ProtocolSupport(vpnProtocols: [.ike, .wireGuard(.udp)]),
            ProtocolSupport([.wireGuardUDP, .ikev2])
        )

    }

}
