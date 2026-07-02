//
//  Created on 25/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

#if DEBUG
    import ExtensionSync
    import IPCDefinitions
    import XCTest

    /// Verifies the exit/user IP fields pack into their binary v4/v6 slots and round-trip back to the same string.
    final class ConnectionDataPayloadIPTests: XCTestCase {
        func testServerExitPacksV4AndV6IntoSeparateSlots() {
            var payload = IPCConnectionDataPayload()
            payload.serverExitV4 = "192.0.2.10"
            payload.serverExitV6 = "2001:db8::1"

            // The dual-stack server exit lands in both dedicated slots, in network byte order, and round-trips.
            XCTAssertEqual(payload.serverExitV4, "192.0.2.10")
            XCTAssertEqual(payload.serverExitV6, "2001:db8::1")
            XCTAssertEqual(withUnsafeBytes(of: payload.server_exit_v4) { Array($0) }, [192, 0, 2, 10])
            XCTAssertTrue(withUnsafeBytes(of: payload.server_exit_v6) { $0.contains { $0 != 0 } })
        }

        func testUserIPRoutesByFamilyIntoTheV6Slot() {
            var payload = IPCConnectionDataPayload()
            payload.userIP = "2001:db8::1"

            XCTAssertEqual(payload.userIP, "2001:db8::1")
            XCTAssertTrue(withUnsafeBytes(of: payload.user_ipv4) { $0.allSatisfy { $0 == 0 } })
            XCTAssertTrue(withUnsafeBytes(of: payload.user_ipv6) { $0.contains { $0 != 0 } })
        }

        func testInvalidServerExitClearsOnlyItsOwnSlot() {
            var payload = IPCConnectionDataPayload()
            payload.serverExitV6 = "2001:db8::1"
            payload.serverExitV4 = "192.0.2.10"
            payload.serverExitV4 = "not-an-ip" // clears the v4 slot only

            XCTAssertEqual(payload.serverExitV4, "")
            XCTAssertTrue(withUnsafeBytes(of: payload.server_exit_v4) { $0.allSatisfy { $0 == 0 } })
            XCTAssertEqual(payload.serverExitV6, "2001:db8::1") // the v6 slot is untouched
        }
    }

#endif
