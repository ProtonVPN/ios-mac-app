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

// Feature with sub features
enum TestNetShieldFeature: AppFeature {
    typealias SubFeature = TestNetShieldType

    static func canUse(_ subFeature: SubFeature, onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool {
        guard featureFlags.netShield else {
            return false
        }
        return subFeature.canUse(on: plan)
    }
}

// Separately defined SubFeature set
enum TestNetShieldType: CaseIterable {
    case off
    case level1
    case level2

    func canUse(on plan: AccountPlan) -> Bool {
        switch self {
        case .off:
            return true
        case .level1, .level2:
            return plan.paid
        }
    }
}

// Feature with no sub features
enum TestB2BFeature: AppFeature {
    typealias SubFeature = Void

    static func canUse(_ subFeature: Void, onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool {
        return plan == .enterprise2022
    }
}

class AuthorizerTests: XCTestCase {

    func testAuthorizationOfFeatureWithNoSubFeatures() throws {
        let authorizer = withDependencies {
            $0.planProvider = .constant(plan: .plus)
            $0.featureFlagProvider = .constant(flags: .allDisabled)
        } operation: {
            LiveFeatureAuthorizer()
        }

        let canUseB2B = authorizer.authorizer(for: TestB2BFeature.self)

        XCTAssertFalse(canUseB2B())

        withDependencies {
            $0.planProvider = .constant(plan: .enterprise2022)
        } operation: {
            XCTAssertTrue(canUseB2B())
        }
    }

    func testAuthorizationBasedOnFeatureFlags() throws {
        let authorizer = withDependencies {
            $0.planProvider = .constant(plan: .plus)
            $0.featureFlagProvider = .constant(flags: .allDisabled)
        } operation: {
            LiveFeatureAuthorizer()
        }

        let canUseNetShield = authorizer.authorizer(for: TestNetShieldFeature.self)

        XCTAssertFalse(canUseNetShield(), "Authorizer should return false when the feature is disabled with flags")

        withDependencies {
            $0.featureFlagProvider = .constant(flags: .allEnabled)
        } operation: {
            XCTAssertTrue(canUseNetShield(), "Authorizer should return true when feature is enabled with flags")
        }
    }

    func testSubFeatureAuthorization() throws {
        let authorizer = withDependencies {
            $0.planProvider = .constant(plan: .free)
            $0.featureFlagProvider = .constant(flags: .allEnabled)
        } operation: {
            LiveFeatureAuthorizer()
        }

        let canUseNetShield = authorizer.authorizer(for: TestNetShieldFeature.self)
        let canUseNetShieldType = authorizer.authorizer(forSubFeatureOf: TestNetShieldFeature.self)

        XCTAssertFalse(canUseNetShield(), "Global authorizer should return false when some sub-features are unavailable")
        XCTAssertTrue(canUseNetShieldType(.off), "Authorizer should return true for available sub-features")
        XCTAssertFalse(canUseNetShieldType(.level1), "Authorizer should return false for unavailable sub-features")

        withDependencies {
            $0.planProvider = .constant(plan: .plus)
        } operation: {
            XCTAssertTrue(canUseNetShield(), "Global authorizer should return true when all sub-features are available")
            XCTAssertTrue(canUseNetShieldType(.level1), "Authorizer should return true for available sub-features")
        }
    }

    /// This test verifies the correctness of `MockFeatureAuthorizer`
    func testAuthorizerInterfaceForTests() {
        let mockAuthorizer = MockFeatureAuthorizer()

        let sut = withDependencies {
            $0.featureAuthorizer = mockAuthorizer
        } operation: {
            TestFeatureImplementation()
        }

        // Verify that MockAuthorizer catches programmer errors (accessing authorization for unregistered feature)
        // When uncommented, these should fail, because this subfeature and feature have not yet been registered

        // Expected: Authorization requested for `off`, but no value was registered under key `TestNetShieldFeature.off`
        // XCTAssertTrue(sut.canUseNetShieldOff)

        // Expected: Authorization requested for `TestB2BFeature`, but no value was registered under key `TestB2BFeature`
        // XCTAssertTrue(sut.canUseB2B)

        mockAuthorizer.registerAuthorization(for: TestB2BFeature.self, to: false)
        XCTAssertFalse(sut.canUseB2B)

        mockAuthorizer.registerAuthorization(for: TestB2BFeature.self, to: true)
        XCTAssertTrue(sut.canUseB2B)

        mockAuthorizer.registerAuthorization(for: TestNetShieldFeature.self, to: false)
        mockAuthorizer.registerAuthorization(forSubFeature: .off, of: TestNetShieldFeature.self, to: true)

        XCTAssertFalse(sut.canUseNetShield)
        XCTAssertTrue(sut.canUseNetShieldOff)
    }
}

struct TestFeatureImplementation {
    @Dependency(\.featureAuthorizer) var authorizer

    var canUseB2B: Bool {
        return authorizer.authorizer(for: TestB2BFeature.self)()
    }

    var canUseNetShield: Bool {
        return authorizer.authorizer(for: TestNetShieldFeature.self)()
    }

    var canUseNetShieldOff: Bool {
        return authorizer.authorizer(forSubFeatureOf: TestNetShieldFeature.self)(.off)
    }
}
