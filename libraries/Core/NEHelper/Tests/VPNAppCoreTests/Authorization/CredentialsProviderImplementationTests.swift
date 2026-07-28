//
//  CredentialsProviderImplementationTests.swift
//  vpncore - Created on 2021-01-06.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Domain
import Testing
@testable import VPNAppCore
@testable import VPNShared

struct CredentialsProviderTests {
    @Test
    func returnsValuesSavedInKeychain() {
        let testPairs: [(String, VpnTier)] = [
            ("free", .free),
            ("plus", .paid),
        ]

        for (plan, tier) in testPairs {
            let keychain = VpnKeychainMock(planName: plan, maxTier: tier)
            let fetchCached: () throws -> CachedVpnCredentials = keychain.fetchCached

            let provider = CredentialsProvider(getCredentials: { try? fetchCached() })

            #expect(provider.tier == tier)
            #expect(provider.planName == plan)
            #expect(provider.hasCredentials)
        }
    }

    @Test
    func returnsSafeDefaultsWhenCredentialsAreUnavailable() {
        let keychain = VpnKeychainMock(planName: "plus", maxTier: .internal)
        keychain.throwsOnFetch = true
        let fetchCached: () throws -> CachedVpnCredentials = keychain.fetchCached

        let provider = CredentialsProvider(getCredentials: { try? fetchCached() })

        #expect(provider.planName == "free")
        #expect(provider.planTitle == nil)
        #expect(provider.tier == .free)
        #expect(!provider.hasCredentials)
        #expect(!provider.isBusiness)
        #expect(!provider.businessEvents)
        #expect(provider.netShield == nil)
    }
}
