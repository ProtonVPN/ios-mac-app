//
//  Created on 10/08/2023.
//
//  Copyright (c) 2023 Proton AG
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
@testable import LegacyCommon

// Feature with no sub features
enum TestB2BFeature: AppFeature {
    static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if plan == "vpnbiz2023" {
            return .success
        }
        return .failure(.requiresUpgrade)
    }
}

enum TestNetShieldType: ModularAppFeature {
    case off
    case level1
    case level2

    func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        guard featureFlags.netShield else {
            return .failure(.featureDisabled)
        }
        switch self {
        case .off:
            return .success
        case .level1, .level2:
            if userTier > CoreAppConstants.VpnTiers.free {
                return .success
            }
            return .failure(.requiresUpgrade)
        }
    }
}

class FeatureAuthorizerProviderTests: XCTestCase {

    func testAuthorizationOfFeatureWithNoSubFeatures() throws {
        let provider = withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
            $0.featureFlagProvider = .constant(flags: .allDisabled)
        } operation: {
            LiveFeatureAuthorizerProvider()
        }

        let canUseB2B = provider.authorizer(for: TestB2BFeature.self)

        XCTAssertEqual(canUseB2B(), .failure(.requiresUpgrade))

        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free, planName: "vpnbiz2023"))
        } operation: {
            XCTAssertEqual(canUseB2B(), .success)
        }
    }

    func testAuthorizationBasedOnFeatureFlags() throws {
        let provider = withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
            $0.featureFlagProvider = .constant(flags: .allDisabled)
        } operation: {
            LiveFeatureAuthorizerProvider()
        }

        let authorizer = provider.authorizer(for: TestNetShieldType.self)

        XCTAssertEqual(authorizer.canUseAnySubFeature, .failure(.featureDisabled))

        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
        } operation: {
            XCTAssertEqual(authorizer.canUseAnySubFeature, .success)
        }
    }

    func testSubFeatureAuthorization() throws {
        let provider = withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free))
            $0.featureFlagProvider = .constant(flags: .allEnabled)
        } operation: {
            LiveFeatureAuthorizerProvider()
        }

        let authorizer = provider.authorizer(for: TestNetShieldType.self)

        XCTAssertEqual(authorizer.canUseAnySubFeature, .success)
        XCTAssertEqual(authorizer.canUseAllSubFeatures, .failure(.requiresUpgrade))
        XCTAssertEqual(authorizer.canUse(.off), .success)
        XCTAssertEqual(authorizer.canUse(.level1), .failure(.requiresUpgrade))

        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
        } operation: {
            XCTAssertEqual(authorizer.canUseAllSubFeatures, .success)
            XCTAssertEqual(authorizer.canUse(.level1), .success)
        }
    }

    /// This test verifies the correctness of `MockFeatureAuthorizer` and that it fails tests when unregistered features are accessed
    func testMockAuthorizerDetectsProgrammerErrors() {
        let mockAuthorizer = MockFeatureAuthorizerProvider()

        let sut = withDependencies {
            $0.featureAuthorizerProvider = mockAuthorizer
        } operation: {
            TestFeatureImplementation()
        }

        // Verification that `MockFeatureAuthorizerProvider` catches programmer errors (accessing authorization for an
        // unregistered feature)
        // When uncommented, these top level assertions should pass, but `MockFeatureAuthorizerProvider` should emit
        // failures underneath, because this subfeature and feature have not yet been registered

        // Expected: Authorization requested for `level2`, but no value was registered under key `TestNetShieldFeature.level2`
        // XCTAssertEqual(sut.netShieldAuthorizer.canUse(.level2), .failure(.requiresUpgrade))

        // Expected: Authorization requested for `TestB2BFeature`, but no value was registered under key `TestB2BFeature`
        // XCTAssertEqual(sut.canUseB2B(), .failure(.requiresUpgrade))

        mockAuthorizer.registerAuthorization(for: TestB2BFeature.self, to: .failure(.requiresUpgrade))
        XCTAssertEqual(sut.canUseB2B(), .failure(.requiresUpgrade))

        mockAuthorizer.registerAuthorization(for: TestB2BFeature.self, to: .success)
        XCTAssertEqual(sut.canUseB2B(), .success)

        mockAuthorizer.registerAuthorization(forSubFeature: TestNetShieldType.level2, to: .success)

        XCTAssertEqual(sut.netShieldAuthorizer.canUse(.level2), .success)

        // Again, these top level assertions should pass, but `MockFeatureAuthorizerProvider` should emit failures
        // underneath

        // Expected: Authorization requested for `off`, but no value was registered under key `TestNetShieldFeature.off`
        // Expected: Authorization requested for `level1`, but no value was registered under key `TestNetShieldFeature.level1`
        // XCTAssertEqual(sut.netShieldAuthorizer.canUseAnySubFeature, .success)
        // XCTAssertEqual(sut.netShieldAuthorizer.canUseAllSubFeatures, .failure(.requiresUpgrade))

        mockAuthorizer.registerAuthorization(forSubFeature: TestNetShieldType.off, to: .success)
        mockAuthorizer.registerAuthorization(forSubFeature: TestNetShieldType.level1, to: .success)

        XCTAssertEqual(sut.netShieldAuthorizer.canUseAnySubFeature, .success)
        XCTAssertEqual(sut.netShieldAuthorizer.canUseAllSubFeatures, .success)
    }
}

struct TestFeatureImplementation {
    let canUseB2B: () -> FeatureAuthorizationResult
    let netShieldAuthorizer: Authorizer<TestNetShieldType>

    init() {
        @Dependency(\.featureAuthorizerProvider) var authorizationProvider
        self.canUseB2B = authorizationProvider.authorizer(for: TestB2BFeature.self)
        self.netShieldAuthorizer = authorizationProvider.authorizer(for: TestNetShieldType.self)
    }
}
