//
//  Created on 21/08/2023.
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

import Dependencies
import Domain
@testable import LegacyCommon
import VPNShared
import VPNSharedTesting
import XCTest

private enum TestFeature: String, ProvidableFeature {
    case on
    case off
    case freeDefault
    case paidDefault

    static func canUse(onPlan _: String, userTier: Int, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        if userTier == 0 {
            return .failure(.requiresUpgrade)
        }
        return .success
    }

    func canUse(onPlan _: String, userTier _: Int, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        switch self {
        case .on, .paidDefault:
            .failure(.requiresUpgrade)
        case .off, .freeDefault:
            .success
        }
    }

    static func defaultValue(onPlan _: String, userTier: Int, featureFlags _: FeatureFlags) -> TestFeature {
        if userTier == 0 {
            return .freeDefault
        }
        return .paidDefault
    }

    static var storageKey = "feature"
    static var event: AppEvent? = .testEvent

    static let legacyConversion: ((Bool) -> TestFeature)? = { $0 ? .on : .off }
}

class AppFeaturePropertyProviderTests: XCTestCase {
    func testReturnsUserSpecificValueFromStorage() {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.paidTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: ["featurebilly": encodedOff])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .off)
        }
    }

    func testReturnsLegacyGlobalValueFromStorageWhenNoUserSpecificValueIsStored() {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.paidTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: ["feature": false]) // value encoded using legacy storage type
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .off)
        }
    }

    func testReturnsDecodableGlobalValueFromStorage() {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.paidTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: ["feature": encodedOff])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .off)
        }
    }

    func testReturnsDefaultValueWhenNoValueIsStored() throws {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.paidTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: [:])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .paidDefault)
        }

        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: [:])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .freeDefault)
        }
    }

    func testReturnsDefaultValueWhenStoredValueRequiresUpgrade() throws {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: ["featurebilly": encodedOn])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.failure(.requiresUpgrade))
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .freeDefault)
        }
    }

    func testStoresValueToUserSpecificStorage() {
        let storage = MemoryStorage(initialValue: [:])
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = storage
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            provider.setValue(TestFeature.off)
            XCTAssertEqual(storage.storage["featurebilly"] as? Data, encodedOff)
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .off)
        }
    }

    func testSendsNotificationWhenUpdatingStoredValue() throws {
        let storage = MemoryStorage(initialValue: [:])
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = storage
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let propertyChangeNotification = XCTNSNotificationExpectation(name: TestFeature.event!.name)

            let provider = AppFeaturePropertyProviderImplementation()
            provider.setValue(TestFeature.off)

            wait(for: [propertyChangeNotification], timeout: 1.0)
        }
    }
}

private let encodedOn = try! JSONEncoder().encode(TestFeature.on)
private let encodedOff = try! JSONEncoder().encode(TestFeature.off)

private func mockKeychain(withUsername username: String) -> MockAuthKeychain {
    let authKeychain = MockAuthKeychain()
    authKeychain.setMockUsername(username)
    return authKeychain
}
