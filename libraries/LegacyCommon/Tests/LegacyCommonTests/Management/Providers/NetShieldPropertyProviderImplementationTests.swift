//
//  NetShieldPropertyProviderImplementationTests.swift
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

import Dependencies

import Domain
import VPNShared
import VPNSharedTesting
@testable import LegacyCommon

final class NetShieldPropertyProviderImplementationTests: XCTestCase {
    static let username = "user1"
    let paidPlans: [AccountPlan] = [.basic, .plus, .visionary]

    override func setUp() {
        super.setUp()
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().removeObject(forKey: "NetShield\(Self.username)")
    }

    func testReturnsSettingFromProperties() throws {
        for type in NetShieldType.allCases {
            withProvider(netShieldType: type, plan: .basic) {
                XCTAssertEqual($0.netShieldType, type)
            }
        }
    }
    
    func testWhenNothingIsSetReturnsLevel1ForPaidUsers() throws {
        for plan in paidPlans {
            withProvider(netShieldType: nil, plan: plan) {
                XCTAssertEqual($0.netShieldType, .level1)
            }
        }
    }
    
    func testWhenNothingIsSetReturnsOffForFreeUsers() throws {
        withProvider(netShieldType: nil, plan: .free) {
            XCTAssertEqual($0.netShieldType, NetShieldType.off)
        }
    }
    
    func testWhenUnavailableOptionIsSetReturnsDefault() throws {
        withProvider(netShieldType: .level2, plan: .free) {
            XCTAssertEqual($0.netShieldType, NetShieldType.off)
        }
    }
    
    func testSavesValueToStorage() {
        withProvider(netShieldType: nil, plan: .basic) { provider in
            var provider = provider
            @Dependency(\.defaultsProvider) var defaultsProvider
            for type in NetShieldType.allCases {
                provider.netShieldType = type
                XCTAssertEqual(defaultsProvider.getDefaults().integer(forKey: "NetShield\(Self.username)"), type.rawValue)
                XCTAssertEqual(provider.netShieldType, type)
            }
        }
    }
    
    func testFreeUserCantTurnNetShieldOn() throws {
        let levels: [NetShieldType] = [.level1, .level2]
        for level in levels {
            XCTAssertEqual(
                getAuthorizer(plan: .free).canUse(level),
                .failure(.requiresUpgrade)
            )
        }
    }
    
    func testPaidUserCanTurnNetShieldOn() throws {
        for plan in paidPlans {
            XCTAssertEqual(getAuthorizer(plan: plan).canUseAllSubFeatures, .success)
        }
    }

    // MARK: - Plan Change tests

    func testNetShieldSetToOffAfterDowngrade() {
        withProvider(netShieldType: .level2, plan: .basic) {
            $0.adjustAfterPlanChange(from: CoreAppConstants.VpnTiers.plus, to: CoreAppConstants.VpnTiers.basic)
            XCTAssertEqual($0.netShieldType, .level2)
        }

        withProvider(netShieldType: .level2, plan: .free) {
            $0.adjustAfterPlanChange(from: CoreAppConstants.VpnTiers.plus, to: CoreAppConstants.VpnTiers.free)
            XCTAssertEqual($0.netShieldType, .off)
        }
    }

    func testNetShieldSetToLevel2AfterUpgradeFromFree() {
        withProvider(netShieldType: .off, plan: .basic) {
            $0.adjustAfterPlanChange(from: CoreAppConstants.VpnTiers.free, to: CoreAppConstants.VpnTiers.basic)
            XCTAssertEqual($0.netShieldType, .level2)
        }
    }

    func testNetShieldNotChangedFromLevel2OnUpgradeFromBasic() {
        withProvider(netShieldType: .level2, plan: .plus) {
            $0.adjustAfterPlanChange(from: CoreAppConstants.VpnTiers.basic, to: CoreAppConstants.VpnTiers.plus)
            XCTAssertEqual($0.netShieldType, .level2)
        }
    }
    
    // MARK: -

    private func withProvider(netShieldType: NetShieldType?, plan: AccountPlan?, flags: FeatureFlags = .allEnabled, closure: @escaping (NetShieldPropertyProvider) -> Void) {
        withDependencies {
            let authKeychain = MockAuthKeychain()
            authKeychain.setMockUsername(Self.username)
            $0.authKeychain = authKeychain

            let credentials: CachedVpnCredentials? = plan == nil ? nil : .plan(plan!)
            $0.credentialsProvider = .constant(credentials: credentials)
            $0.featureFlagProvider = .constant(flags: flags)
            $0.featureAuthorizerProvider = LiveFeatureAuthorizerProvider()
        } operation: {
            @Dependency(\.defaultsProvider) var defaultsProvider
            defaultsProvider.getDefaults()
                .setUserValue(netShieldType?.rawValue, forKey: "NetShield")

            closure(NetShieldPropertyProviderImplementation())
        }
    }

    func getAuthorizer(plan: AccountPlan) -> Authorizer<NetShieldType> {
        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.credentialsProvider = .constant(credentials: .plan(plan))
        } operation: {
            return LiveFeatureAuthorizerProvider()
                .authorizer(for: NetShieldType.self)
        }
    }
}
