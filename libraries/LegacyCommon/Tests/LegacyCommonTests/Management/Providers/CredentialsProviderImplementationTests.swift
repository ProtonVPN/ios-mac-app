//
//  AccountPlanProviderImplementationTests.swift
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

import XCTest
@testable import LegacyCommon

class CredentialsProviderImplementationTests: XCTestCase {

    func testReturnsTierSavedInKeychain() throws {
        let testPairs: [(AccountPlan, Int)] = [
            (AccountPlan.free, CoreAppConstants.VpnTiers.free),
            (AccountPlan.basic, CoreAppConstants.VpnTiers.basic),
            (AccountPlan.plus, CoreAppConstants.VpnTiers.visionary),
            (AccountPlan.visionary, CoreAppConstants.VpnTiers.visionary),
        ]
        
        for (plan, tier) in testPairs {
            let keychain = VpnKeychainMock(accountPlan: plan, maxTier: tier)

            let provider = CredentialsProvider {
                try? keychain.fetchCached()
            }

            XCTAssertEqual(provider.tier, tier)
            XCTAssertEqual(provider.plan, plan)
        }
    }
    
    func testReturnsFreeTierIfNoneIsAvilable() throws {
        let keychain = VpnKeychainMock(accountPlan: AccountPlan.plus, maxTier: CoreAppConstants.VpnTiers.visionary)
        keychain.throwsOnFetch = true

        let provider = CredentialsProvider {
            try? keychain.fetchCached()
        }

        XCTAssertEqual(provider.plan, .free)
        XCTAssertEqual(provider.tier, CoreAppConstants.VpnTiers.free)
    }
}
