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
    private let paidTiers: [Int] = [CoreAppConstants.VpnTiers.basic, CoreAppConstants.VpnTiers.plus, CoreAppConstants.VpnTiers.internal]

    override func setUp() {
        super.setUp()
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().removeObject(forKey: "NATType\(Self.username)")
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [NATType] = NATType.allCases

        for type in variants {
            withProvider(natType: type, tier: CoreAppConstants.VpnTiers.plus) {
                XCTAssertEqual($0.natType, type)
            }
        }
    }

    func testWhenNothingIsSetReturnsStrict() throws {
        for tier in paidTiers {
            withProvider(natType: nil, tier: tier) { provider in
                XCTAssertEqual(provider.natType, NATType.strictNAT)
            }
        }
    }

    func testSavesValueToStorage() {
        withProvider(natType: nil, tier: CoreAppConstants.VpnTiers.plus) { provider in
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
        XCTAssertEqual(getAuthorizer(tier: CoreAppConstants.VpnTiers.free), .failure(.requiresUpgrade))
    }

    func testPaidUserCanTurnModerateNATOn() throws {
        let tiers: [Int] = [CoreAppConstants.VpnTiers.basic, CoreAppConstants.VpnTiers.plus, CoreAppConstants.VpnTiers.internal]
        for tier in tiers {
            XCTAssertEqual(getAuthorizer(tier: tier), .success)
        }
    }

    func withProvider(natType: NATType?, tier: Int, flags: FeatureFlags = .allDisabled, closure: @escaping (NATTypePropertyProvider) -> Void) {
        withDependencies {
            let authKeychain = MockAuthKeychain()
            authKeychain.setMockUsername(Self.username)
            $0.authKeychain = authKeychain

            $0.credentialsProvider = .constant(credentials: .tier(tier))
            $0.featureFlagProvider = .constant(flags: flags)
            $0.featureAuthorizerProvider = LiveFeatureAuthorizerProvider()
        } operation: {
            @Dependency(\.defaultsProvider) var defaultsProvider
            defaultsProvider.getDefaults()
                .setUserValue(natType?.rawValue, forKey: "NATType")
            
            closure(NATTypePropertyProviderImplementation())
        }
    }

    func getAuthorizer(tier: Int) -> FeatureAuthorizationResult {
        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.credentialsProvider = .constant(credentials: .tier(tier))
        } operation: {
            let authorizer = LiveFeatureAuthorizerProvider()
                .authorizer(for: NATFeature.self)
            return authorizer()
        }
    }
}
