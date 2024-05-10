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
            withProvider(safeMode: type, tier: .paidTier) {
                XCTAssertEqual($0.safeMode, type)
            }
        }
    }

    func testReturnsSettingFromPropertiesWhenDisabledByFeatureFlag() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            withProvider(safeMode: type, tier: .paidTier, flags: .init(safeMode: false)) {
                XCTAssertNil($0.safeMode)
            }
        }
    }

    func testWhenNothingIsSetReturnsTrue() throws {
        withProvider(safeMode: nil, tier: .paidTier) {
            XCTAssertTrue($0.safeMode ?? false)
        }
    }

    func testWhenNothingIsSetReturnsFalseWhenDisabledByFeatureFlag() throws {
        withProvider(safeMode: nil, tier: .paidTier, flags: .init(safeMode: false)) {
            XCTAssertNil($0.safeMode)
        }
    }

    func testSavesValueToStorage() {
        withProvider(safeMode: nil, tier: .paidTier) { provider in
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
        XCTAssertEqual(getAuthorizer(tier: .freeTier), .failure(.requiresUpgrade))
    }

    func testPaidUserCanTurnOffSafeMode() throws {
        XCTAssertEqual(getAuthorizer(tier: .paidTier), .success)
    }

    // MARK: -

    func withProvider(safeMode: Bool?, tier: Int, flags: FeatureFlags = .allEnabled, closure: @escaping (SafeModePropertyProvider) -> Void) {
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
                .setUserValue(safeMode, forKey: "SafeMode")
            closure(SafeModePropertyProviderImplementation())
        }
    }

    func getAuthorizer(tier: Int) -> FeatureAuthorizationResult {
        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.credentialsProvider = .constant(credentials: .tier(tier))
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
            unsafeLanWarnings: true,
            mismatchedCertificateRecovery: true,
            localOverrides: nil
        )
    }
}
