//
//  Created on 21.02.2022.
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

import XCTest

import Dependencies

import Domain
import VPNShared
import VPNSharedTesting

@testable import LegacyCommon

final class NATTypePropertyProviderImplementationTests: XCTestCase {
    static let username = "user1"
    private let paidPlans: [AccountPlan] = [.basic, .plus, .visionary]

    override func setUp() {
        super.setUp()
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().removeObject(forKey: "NATType\(Self.username)")
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [NATType] = NATType.allCases

        for type in variants {
            withProvider(natType: type, plan: .plus) {
                XCTAssertEqual($0.natType, type)
            }
        }
    }

    func testWhenNothingIsSetReturnsStrict() throws {
        for plan in paidPlans {
            withProvider(natType: nil, plan: plan) { provider in
                XCTAssertEqual(provider.natType, NATType.strictNAT)
            }
        }
    }

    func testSavesValueToStorage() {
        withProvider(natType: nil, plan: .plus) { provider in
            var provider = provider
            for type in NATType.allCases {
                provider.natType = type
                @Dependency(\.defaultsProvider) var defaultsProvider
                XCTAssertEqual(defaultsProvider.getDefaults().integer(forKey: "NATType\(Self.username)"), type.rawValue)
                XCTAssertEqual(provider.natType, type)
            }
        }
    }

    func testFreeUserCantTurnModerateNATOn() throws {
        XCTAssertEqual(getAuthorizer(plan: .free), .failure(.requiresUpgrade))
    }

    func testPaidUserCanTurnModerateNATOn() throws {
        let accountPlans: [AccountPlan] = [.basic, .plus, .visionary]
        for plan in accountPlans {
            XCTAssertEqual(getAuthorizer(plan: plan), .success)
        }
    }

    func withProvider(natType: NATType?, plan: AccountPlan, flags: FeatureFlags = .allDisabled, closure: @escaping (NATTypePropertyProvider) -> Void) {
        withDependencies {
            let authKeychain = MockAuthKeychain()
            authKeychain.setMockUsername(Self.username)
            $0.authKeychain = authKeychain

            $0.credentialsProvider = .constant(credentials: .plan(plan))
            $0.featureFlagProvider = .constant(flags: flags)
            $0.featureAuthorizerProvider = LiveFeatureAuthorizerProvider()
        } operation: {
            @Dependency(\.defaultsProvider) var defaultsProvider
            defaultsProvider.getDefaults()
                .setUserValue(natType?.rawValue, forKey: "NATType")
            
            closure(NATTypePropertyProviderImplementation())
        }
    }

    func getAuthorizer(plan: AccountPlan) -> FeatureAuthorizationResult {
        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.credentialsProvider = .constant(credentials: .plan(plan))
        } operation: {
            let authorizer = LiveFeatureAuthorizerProvider()
                .authorizer(for: NATFeature.self)
            return authorizer()
        }
    }
}
