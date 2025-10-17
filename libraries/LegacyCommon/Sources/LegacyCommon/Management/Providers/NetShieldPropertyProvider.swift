//
//  NetShieldPropertyProvider.swift
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

import Foundation

import Dependencies

import VPNShared

import Domain
import Ergonomics

public struct NetShieldPropertyProvider {
    /// Get the current NetShield type
    public var getNetShieldType: () -> NetShieldType

    /// Set the NetShield type
    public var setNetShieldType: (NetShieldType) -> Void

    /// Get the last active (non-off) NetShield type
    public var getLastActiveNetShieldType: () -> NetShieldType

    /// Adjust settings after plan change
    public var adjustAfterPlanChangeClosure: (_ from: Int, _ to: Int) -> Void

    public init(
        getNetShieldType: @escaping () -> NetShieldType,
        setNetShieldType: @escaping (NetShieldType) -> Void,
        getLastActiveNetShieldType: @escaping () -> NetShieldType,
        adjustAfterPlanChange: @escaping (Int, Int) -> Void
    ) {
        self.getNetShieldType = getNetShieldType
        self.setNetShieldType = setNetShieldType
        self.getLastActiveNetShieldType = getLastActiveNetShieldType
        self.adjustAfterPlanChangeClosure = adjustAfterPlanChange
    }
}

extension NetShieldPropertyProvider: FeaturePropertyProvider {
    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        adjustAfterPlanChangeClosure(oldTier, tier)
    }
}

extension NetShieldType: ModularAppFeature {
    public func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}

extension NetShieldType: PaidAppFeature {
    public static func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if level1.isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}

// MARK: - Dependency Key

extension NetShieldPropertyProvider: DependencyKey {
    private enum StorageKey: String {
        case netShield = "NetShield"
        case lastActive = "LastActiveNetShield"
    }

    public static let liveValue: Self = {
        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
        @Dependency(\.defaultsProvider) var defaultsProvider

        let authorizer = featureAuthorizerProvider.authorizer(forSubFeatureOf: NetShieldType.self)

        let getStoredNetShieldValue: (StorageKey) -> NetShieldType? = { key in
            let rawValue = defaultsProvider.getDefaults().userValue(forKey: key.rawValue)

            guard let intValue = rawValue as? Int else {
                log.info("Failed to retrieve stored NetShield level, stored value is either nil or not an Int: \(String(describing: rawValue))", category: .settings)
                return nil
            }

            guard let type = NetShieldType(rawValue: intValue) else {
                log.error("Failed to retrieve stored NetShield level, \(intValue) is not a valid NetShield type", category: .settings)
                return nil
            }

            guard authorizer(type).isAllowed else {
                log.info("User account has NetShield disabled", category: .settings)
                let defaultNetShieldType = authorizer(.level2) == .success ? NetShieldType.level2 : .off
                return defaultNetShieldType
            }

            return type
        }

        let defaultNetShieldType: () -> NetShieldType = {
            authorizer(.level2) == .success ? .level2 : .off
        }

        let getNetShieldType: () -> NetShieldType = {
            guard let value = getStoredNetShieldValue(.netShield) else {
                let defaultType = defaultNetShieldType()
                log.info("NetShield setting not found, setting to default (\(defaultType))", category: .settings)
                defaultsProvider.getDefaults().setUserValue(defaultType.rawValue, forKey: StorageKey.netShield.rawValue)
                return defaultType
            }
            return value
        }

        return Self(
            getNetShieldType: getNetShieldType,
            setNetShieldType: { newValue in
                var success = defaultsProvider
                    .getDefaults()
                    .setUserValue(
                        newValue.rawValue,
                        forKey: StorageKey.netShield.rawValue
                    )
                if newValue != .off {
                    // Duplicate active NS level, so that we can remember it to toggle it between off/on (V1 UI)
                    success = defaultsProvider
                        .getDefaults()
                        .setUserValue(
                            newValue.rawValue,
                            forKey: StorageKey.lastActive.rawValue
                        )
                }

                if success {
                    executeOnUIThread {
                        AppEvent.netShield.post(newValue)
                    }
                }
            },
            getLastActiveNetShieldType: {
                guard let lastActiveType = getStoredNetShieldValue(.lastActive) else {
                    let currentType = getNetShieldType()
                    log.warning("Last active NetShield type is nil, defaulting to \(currentType)")
                    return currentType
                }
                return lastActiveType
            },
            adjustAfterPlanChange: { oldTier, tier in
                // Turn NetShield off on downgrade to free plan
                if tier.isFreeTier {
                    defaultsProvider.getDefaults().setUserValue(NetShieldType.off.rawValue, forKey: StorageKey.netShield.rawValue)
                    executeOnUIThread {
                        AppEvent.netShield.post(NetShieldType.off)
                    }
                }
                // On upgrade from the free plan, switch NetShield to the default value for the new tier
                if tier > oldTier, oldTier.isFreeTier {
                    defaultsProvider.getDefaults().setUserValue(NetShieldType.level2.rawValue, forKey: StorageKey.netShield.rawValue)
                    executeOnUIThread {
                        AppEvent.netShield.post(NetShieldType.level2)
                    }
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = .init(
            getNetShieldType: { .off },
            setNetShieldType: { _ in },
            getLastActiveNetShieldType: { .level1 },
            adjustAfterPlanChange: { _, _ in }
        )
    #endif
}

public extension DependencyValues {
    var netShieldPropertyProvider: NetShieldPropertyProvider {
        get { self[NetShieldPropertyProvider.self] }
        set { self[NetShieldPropertyProvider.self] = newValue }
    }
}
