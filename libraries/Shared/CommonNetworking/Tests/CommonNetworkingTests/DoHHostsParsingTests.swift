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

import CommonNetworking
import Dependencies
import Foundation
import Testing

struct DoHHostsParsingTests {
    @Test
    func parsesHostsForLiveEnvironment() {
        let doh = DoHVPN(
            apiHost: "",
            verifyHost: "verify.proton",
            alternativeRouting: true,
            isConnected: false
        )

        #expect(doh.defaultHost == "https://vpn-api.proton.me")
        #expect(doh.accountHost == "https://account.proton.me")
        #expect(doh.humanVerificationV3Host == "verify.proton")
        #expect(!doh.isAtlasRequest)
    }

    /// A custom host is used verbatim as the default host, while the account and human
    /// verification hosts are derived from its base domain — with or without a `vpn.` prefix.
    @Test(arguments: ["https://example.com", "https://vpn.example.com"])
    func parsesHostsForAtlasEnvironment(customHost: String) {
        withDependencies {
            $0.customHostValidator = .debug
        } operation: {
            let doh = DoHVPN(
                apiHost: "",
                verifyHost: "",
                alternativeRouting: true,
                customHost: customHost,
                isConnected: false
            )

            #expect(doh.defaultHost == customHost)
            #expect(doh.accountHost == "https://account.example.com")
            #expect(doh.humanVerificationV3Host == "https://verify.example.com")
            #expect(doh.isAtlasRequest)
        }
    }
}
