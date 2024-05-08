//
//  Created on 02.05.2022.
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
import XCTest
import CommonNetworking
@testable import LegacyCommon

class DoHHostsParsingTests: XCTestCase {
    func testHostParsingForLiveEnvironment() {
        let doh = DoHVPN(
            apiHost: "",
            verifyHost: "verify.proton",
            alternativeRouting: true,
            isConnected: false,
            isAppStateNotificationConnected: { _ in false }
        )

        XCTAssertEqual(doh.defaultHost, "https://vpn-api.proton.me")
        XCTAssertEqual(doh.accountHost, "https://account.proton.me")
        XCTAssertEqual(doh.humanVerificationV3Host, "verify.proton")
        XCTAssertFalse(doh.isAtlasRequest)
    }

    func testHostParsingForAtlasEnvironment() {
        let doh = DoHVPN(
            apiHost: "",
            verifyHost: "",
            alternativeRouting: true,
            customHost: "https://example.com",
            isConnected: false,
            isAppStateNotificationConnected: { _ in false }
        )

        XCTAssertEqual(doh.defaultHost, "https://example.com")
        XCTAssertEqual(doh.accountHost, "https://account.example.com")
        XCTAssertEqual(doh.humanVerificationV3Host, "https://verify.example.com")
        XCTAssertTrue(doh.isAtlasRequest)
    }

    func testHostParsingForVPNAtlasEnvironment() {
        let doh = DoHVPN(
            apiHost: "",
            verifyHost: "",
            alternativeRouting: true,
            customHost: "https://vpn.example.com",
            isConnected: false,
            isAppStateNotificationConnected: { _ in false }
        )

        XCTAssertEqual(doh.defaultHost, "https://vpn.example.com")
        XCTAssertEqual(doh.accountHost, "https://account.example.com")
        XCTAssertEqual(doh.humanVerificationV3Host, "https://verify.example.com")
        XCTAssertTrue(doh.isAtlasRequest)
    }
}
