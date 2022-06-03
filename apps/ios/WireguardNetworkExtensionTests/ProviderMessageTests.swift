//
//  Created on 2022-06-03.
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

class ProviderMessageTests: XCTestCase {
    func testProviderResponses() {
        let messages: [WireguardProviderRequest.Response] = [
            .ok(data: "This is a test message".data(using: .utf8)),
            .ok(data: ("This is a rather long message that will go on and on and on and on and on and on and on " +
                      "and on and on and on and on and on and on and on and on and on and on and on and on and on " +
                      "and on and on and on and on and on and on and on and on and on and on and on and on and on " +
                      "and on and on and on and on and on and on and on and on and on and on and on and on and on " +
                      "and on and on and on and on and on and on and on and on and on and on and on and on and on.")
                .data(using: .utf8)),
            .ok(data: Data(repeating: 0, count: 4096)),
            .ok(data: nil),
            .error(message: "This is an error message"),
            .errorTooManyCertRequests(retryAfter: 15213),
            .errorTooManyCertRequests(retryAfter: nil),
            .errorSessionExpired,
            .errorNeedKeyRegeneration
        ]

        for message in messages {
            XCTAssertEqual(try? WireguardProviderRequest.Response.decode(data: message.asData), message,
                           "Expected \(message) to be equal after decoding")
        }
    }

    func testProviderRequests() {
        let messages: [WireguardProviderRequest] = [
            .getRuntimeTunnelConfiguration,
            .cancelRefreshes,
            .restartRefreshes,
            .refreshCertificate(features: .init(netshield: .level1,
                                                vpnAccelerator: true,
                                                bouncing: "bouncing",
                                                natType: .moderateNAT,
                                                safeMode: true)),
            .refreshCertificate(features: nil),
            .flushLogsToFile,
            .setApiSelector("SELECTOR")
        ]

        for message in messages {
            XCTAssertEqual(try? WireguardProviderRequest.decode(data: message.asData), message,
                           "Expected \(message) to be equal after decoding")
        }
    }
}
