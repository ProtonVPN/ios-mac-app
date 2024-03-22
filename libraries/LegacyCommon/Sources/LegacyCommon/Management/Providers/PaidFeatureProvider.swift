//
//  Created on 17/08/2023.
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

import Foundation
import Dependencies
import Ergonomics

public protocol AppFeaturePropertyProvider {
    func getValue<T: ProvidableFeature>(for feature: T.Type) -> T
    func setValue<T: ProvidableFeature>(_ value: T)
}

public struct AppFeaturePropertyProviderKey: DependencyKey {
    public static var liveValue: AppFeaturePropertyProvider { AppFeaturePropertyProviderImplementation() }
    #if DEBUG
    public static var testValue: AppFeaturePropertyProvider {
        let provider = MockFeaturePropertyProvider()
        provider.setValue(VPNAccelerator.on)
        provider.setValue(ExcludeLocalNetworks.on)
        return provider
    }
    #endif
}

extension DependencyValues {
    public var appFeaturePropertyProvider: AppFeaturePropertyProvider {
        get { self[AppFeaturePropertyProviderKey.self] }
        set { self[AppFeaturePropertyProviderKey.self] = newValue }
    }
}

class AppFeaturePropertyProviderImplementation: AppFeaturePropertyProvider {
    @Dependency(\.featureAuthorizerProvider) private var authorizerProvider
    @Dependency(\.featureFlagProvider) private var featureFlagProvider
    @Dependency(\.credentialsProvider) private var credentialsProvider
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.storage) private var storage

    private func defaultValueForCurrentUser<T: ProvidableFeature>(for feature: T.Type) -> T {
        return feature.defaultValue(
            onPlan: credentialsProvider.planName,
            userTier: credentialsProvider.tier,
            featureFlags: featureFlagProvider.getFeatureFlags()
        )
    }

    private func authorization<T: AppFeature>(for feature: T.Type) -> FeatureAuthorizationResult {
        let authorizer = authorizerProvider.authorizer(for: feature)
        return authorizer()
    }

    private func authorization<T: ModularAppFeature>(for value: T) -> FeatureAuthorizationResult {
        let authorizer = authorizerProvider.authorizer(forSubFeatureOf: T.self)
        return authorizer(value)
    }

    /// Deletes any previous value found to prevent it from acting as a new default value for all users
    private func fetchAndDeleteStoredLegacyValue<T: ProvidableFeature>(
        for feature: T.Type,
        using conversion: ((T.LegacyStorageType) -> T)
    ) -> T? {
        // Check if there is a decodable value stored for the global setting
        do {
            if let globalValue = try storage.get(T.self, forKey: feature.storageKey) {
                storage.removeObject(forKey: feature.storageKey)
                return globalValue
            }
        } catch {
            log.error("Failed to decode legacy value for feature \(T.self) for the current user with error \(error)")
        }

        // Check if there is an (primitive) object stored for the global setting and try to cast it
        if let object = storage.getValue(forKey: feature.storageKey) {
            storage.removeObject(forKey: feature.storageKey)
            if let value = object as? T.LegacyStorageType {
                return conversion(value)
            } else {
                log.error("Could not cast global legacy value for feature (\(object)) to \(T.LegacyStorageType.self)")
            }
        }
        return nil
    }

    private func getStoredValue<T: ProvidableFeature>(for feature: T.Type) -> T? {
        // Check storage for a user specific value
        do {
            if let value = try storage.getForUser(T.self, forKey: feature.storageKey) {
                return value
            }
        } catch {
            log.error("Failed to fetch value for feature \(T.self) for the current user with error \(error)")
        }

        if let legacyConversion = feature.legacyConversion {
            if let legacyValue = fetchAndDeleteStoredLegacyValue(for: feature, using: legacyConversion) {
                setValue(legacyValue)
                return legacyValue
            }
        }
        return nil
    }

    func getValue<T: ProvidableFeature>(for feature: T.Type) -> T {
        let defaultValue = defaultValueForCurrentUser(for: feature)
        guard authorization(for: feature).isAllowed else {
            log.debug("User is not authorized for feature \(feature), returning default value \(defaultValue)")
            return defaultValue
        }

        guard let storedValue = getStoredValue(for: feature) else {
            let value = defaultValueForCurrentUser(for: feature)
            log.debug("Value for feature \(T.self) not found in storage, storing and returning default value (\(value))")
            setValue(value)
            return value
        }

        let authorizationResult = authorization(for: storedValue)
        guard authorizationResult.isAllowed else {
            log.info("Authorization of \(storedValue): \(authorizationResult) for the current user, returning default")
            return defaultValueForCurrentUser(for: feature)
        }
        return storedValue
    }

    func setValue<T: ProvidableFeature & Encodable>(_ value: T) {
        do {
            guard try storage.setForUser(value, forKey: T.storageKey) else {
                log.error("Failed to store value for feature \(T.self) for the current user")
                return
            }
            log.debug("Value for feature \(T.self) updated to \(value)")
            notifyOfChange(to: value)
        } catch {
            log.error("Failed to store value for feature \(T.self) for the current user with error: \(error)")
        }
    }

    private func notifyOfChange<T: ProvidableFeature>(to value: T) {
        guard let notificationName = T.notificationName else {
            return
        }
        executeOnUIThread {
            // `value` is being passed as the `object` for historical reasons (compatibility with existing listeners),
            // but ideally the value passed as the `object` should be the poster of the notification (i.e. `self`), and
            // any data should be passed through the `userInfo` parameter (or using a type-safe mechanism like
            // Strong-Notification). Not passing `self` can make it difficult implement notification tests (see
            // `XCTNSNotificationExpectation`)
            NotificationCenter.default.post(name: notificationName, object: value, userInfo: nil)
        }
    }
}

#if DEBUG
public class MockFeaturePropertyProvider: AppFeaturePropertyProvider {
    public var featureValueMap: [String: Any] = [:]

    public init() { }

    private func featureKey<T: ProvidableFeature>(for feature: T.Type) -> String {
        return "\(feature)"
    }

    public func getValue<T: ProvidableFeature>(for feature: T.Type) -> T {
        let key = featureKey(for: feature)
        guard let storedValue = featureValueMap[key] else {
            XCTFail("Value requested for feature '\(feature)', but no value was registered under key '\(key)'")
            return feature.defaultValue(onPlan: "free", userTier: 0, featureFlags: .allEnabled)
        }
        guard let value = storedValue as? T else {
            XCTFail("Incorrect value type stored for feature '\(feature)': '\(storedValue)'")
            return feature.defaultValue(onPlan: "free", userTier: 0, featureFlags: .allEnabled)
        }
        return value
    }

    public func setValue<T: ProvidableFeature>(_ value: T) {
        featureValueMap[featureKey(for: T.self)] = value
    }
}
#endif
