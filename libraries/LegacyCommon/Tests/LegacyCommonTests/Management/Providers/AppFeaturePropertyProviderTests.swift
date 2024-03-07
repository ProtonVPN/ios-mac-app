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

import XCTest
import Dependencies
import VPNShared
import VPNSharedTesting
@testable import LegacyCommon

fileprivate enum TestFeature: String, ProvidableFeature {

    case on
    case off
    case freeDefault
    case paidDefault

    static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if userTier == 0 {
            return .failure(.requiresUpgrade)
        }
        return .success
    }

    func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        switch self {
        case .on, .paidDefault:
            return .failure(.requiresUpgrade)
        case .off, .freeDefault:
            return .success
        }
    }

    static func defaultValue(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> TestFeature {
        if userTier == 0 {
            return .freeDefault
        }
        return .paidDefault
    }

    static var storageKey = "feature"
    static var notificationName: Notification.Name? = Notification.Name("ch.protonvpn.test.feature.changed")

    static let legacyConversion: ((Bool) -> TestFeature)? = { $0 ? .on : .off }

}

class AppFeaturePropertyProviderTests: XCTestCase {

    func testReturnsUserSpecificValueFromStorage() {
        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = MemoryStorage(initialValue: [:])
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let provider = AppFeaturePropertyProviderImplementation()
            XCTAssertEqual(provider.getValue(for: TestFeature.self), .paidDefault)
        }

        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free))
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
            $0.credentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.free))
            $0.authKeychain = mockKeychain(withUsername: "billy")
            $0.featureFlagProvider = .constant(flags: .allEnabled)
            $0.storage = storage
            $0.featureAuthorizerProvider = FeatureAuthorizerKey.constant(.success)
        } operation: {
            let propertyChangeNotification = XCTNSNotificationExpectation(name: TestFeature.notificationName!)

            let provider = AppFeaturePropertyProviderImplementation()
            provider.setValue(TestFeature.off)

            wait(for: [propertyChangeNotification], timeout: 1.0)
        }
    }
}

fileprivate let encodedOn = { try! JSONEncoder().encode(TestFeature.on) }()
fileprivate let encodedOff = { try! JSONEncoder().encode(TestFeature.off) }()

fileprivate func mockKeychain(withUsername username: String) -> MockAuthKeychain {
    let authKeychain = MockAuthKeychain()
    authKeychain.setMockUsername(username)
    return authKeychain
}
