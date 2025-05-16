//
//  Created on 24/04/2025 by adam.
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

import Testing
@testable import Hermes

@Test
func edgeCasesValidation() {
    #expect(HermesResolverLocationValidator.isValid("") == nil)
    #expect(HermesResolverLocationValidator.isValid("🛜") == nil)
    #expect(HermesResolverLocationValidator.isValid(String(repeating: ".", count: 1024)) == nil)
}

@Test
func ipv4Validation() {
    #expect(HermesResolverLocationValidator.isValid("10.2.0.1.") == nil)
    #expect(HermesResolverLocationValidator.isValid("10.2.0.") == nil)
    #expect(HermesResolverLocationValidator.isValid("10...") == nil)
    #expect(HermesResolverLocationValidator.isValid("256.256.256.256") == nil)
    #expect(HermesResolverLocationValidator.isValid("0.0.0.0") == nil)

    #expect(HermesResolverLocationValidator.isValid("10.2.0.1") == .classic)
    #expect(HermesResolverLocationValidator.isValid("1.1.1.1") == .classic)
    #expect(HermesResolverLocationValidator.isValid("255.255.255.255") == .classic)
}

@Test
func ipv6Validation() {
    let invalidIPv6Addresses = [
        "2001:db8:85a3::8a2e:370:7334:",
        "2001:db8:85a3:::8a2e:370:7334",
        "1200::AB00:1234::2552:7777:1313",
        "2001:db8:85a3::8a2e:370g:7334",
        "2001:db8:85a3",
        "12345::",
        "1::2::3",
        ":",
        "",
    ]

    for address in invalidIPv6Addresses {
        #expect(HermesResolverLocationValidator.isValid(address) == nil)
    }

    let validIPv6Addresses = [
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
        "2001:db8:85a3:0:0:8a2e:370:7334",
        "2001:db8:85a3::8a2e:370:7334",
        "::1",
        "::",
        "fe80::1ff:fe23:4567:890a",
        "2001:db8::",
        "2001:0db8::1:0:0:1",
        "0:0:0:0:0:0:0:1",
        "FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF"
    ]

    for address in validIPv6Addresses {
        #expect(HermesResolverLocationValidator.isValid(address) == .classic)
    }
}

@Test(.disabled())
func httpsValidation() {
    #expect(HermesResolverLocationValidator.isValid("https://") == nil)
    #expect(HermesResolverLocationValidator.isValid("https:/1.1.1.1") == nil)
    #expect(HermesResolverLocationValidator.isValid("http://1.1.1.1") == nil)

    #expect(HermesResolverLocationValidator.isValid("https://1.1.1.1") == .doh)
    #expect(HermesResolverLocationValidator.isValid("https://dns.google") == .doh)
    #expect(HermesResolverLocationValidator.isValid("https://dns.google/dns-query") == .doh)
}

@Test(.disabled())
func tlsValidation() {
    #expect(HermesResolverLocationValidator.isValid("tls://") == nil)
    #expect(HermesResolverLocationValidator.isValid("tls:/1.1.1.1") == nil)

    #expect(HermesResolverLocationValidator.isValid("tls://1.1.1.1") == .tls)
    #expect(HermesResolverLocationValidator.isValid("tls://someUUID.dns.nextdns.io") == .tls)
}
