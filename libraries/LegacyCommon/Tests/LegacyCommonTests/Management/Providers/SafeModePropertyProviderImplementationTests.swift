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
import VPNShared
import VPNSharedTesting
@testable import LegacyCommon

final class SafeModePropertyProviderImplementationTests: XCTestCase {
    static let username = "user1"

    func testReturnsSettingFromProperties() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            withProvider(safeMode: type, plan: .plus) {
                XCTAssertEqual($0.safeMode, type)
            }
        }
    }

    func testReturnsSettingFromPropertiesWhenDisabledByFeatureFlag() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            withProvider(safeMode: type, plan: .plus, flags: .init(safeMode: false)) {
                XCTAssertNil($0.safeMode)
            }
        }
    }

    func testWhenNothingIsSetReturnsTrue() throws {
        let plans: [AccountPlan] = [.basic, .plus, .visionary]
        for plan in plans {
            withProvider(safeMode: nil, plan: plan) {
                XCTAssertTrue($0.safeMode ?? false)
            }
        }
    }

    func testWhenNothingIsSetReturnsFalseWhenDisabledByFeatureFlag() throws {
        let plans: [AccountPlan] = [.basic, .plus, .visionary]
        for plan in plans {
            withProvider(safeMode: nil, plan: plan, flags: .init(safeMode: false)) {
                XCTAssertNil($0.safeMode)
            }
        }
    }

    func testSavesValueToStorage() {
        withProvider(safeMode: nil, plan: .plus) { provider in
            var provider = provider
            @Dependency(\.defaultsProvider) var defaultsProvider

            for type in [true, false] {
                provider.safeMode = type
                XCTAssertEqual(defaultsProvider.getDefaults().object(forKey: "SafeMode\(Self.username)") as? Bool, type)
                XCTAssertEqual(provider.safeMode, type)
            }
        }
    }

    func testFreeUserCantTurnOffSafeMode() throws {
        XCTAssertEqual(getAuthorizer(plan: .free), .failure(.requiresUpgrade))
    }

    func testPaidUserCanTurnOffSafeMode() throws {
        XCTAssertEqual(getAuthorizer(plan: .basic), .success)
        XCTAssertEqual(getAuthorizer(plan: .plus), .success)
        XCTAssertEqual(getAuthorizer(plan: .visionary), .success)
        XCTAssertEqual(getAuthorizer(plan: .vpnbiz2023), .success)
    }

    // MARK: -

    func withProvider(safeMode: Bool?, plan: AccountPlan, flags: FeatureFlags = .allEnabled, closure: @escaping (SafeModePropertyProvider) -> Void) {
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
                .setUserValue(safeMode, forKey: "SafeMode")
            closure(SafeModePropertyProviderImplementation())
        }
    }

    func getAuthorizer(plan: AccountPlan) -> FeatureAuthorizationResult {
        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.credentialsProvider = .constant(credentials: .plan(plan))
        } operation: {
            let authorizer = LiveFeatureAuthorizerProvider()
                .authorizer(for: SafeModeFeature.self)
            return authorizer()
        }
    }
}

private extension FeatureFlags {
    init(safeMode: Bool) {
        self.init(
            smartReconnect: true,
            vpnAccelerator: true,
            netShield: true,
            netShieldStats: true,
            streamingServicesLogos: true,
            portForwarding: true,
            moderateNAT: true,
            pollNotificationAPI: true,
            serverRefresh: true,
            guestHoles: true,
            safeMode: safeMode,
            promoCode: true,
            wireGuardTls: true,
            enforceDeprecatedProtocols: true,
            showNewFreePlan: true,
            unsafeLanWarnings: true,
            localOverrides: nil
        )
    }
}
