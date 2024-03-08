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

import Domain
import LocalFeatureFlags
import VPNShared

public protocol NetShieldPropertyProvider: FeaturePropertyProvider {
    /// Current NetShield type
    var netShieldType: NetShieldType { get set }

    /// Used to store last non-off NS level when toggling NS off <-> on in NS V1 UI
    var lastActiveNetShieldType: NetShieldType { get }

    static var netShieldNotification: Notification.Name { get }
}

public protocol NetShieldPropertyProviderFactory {
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider
}

public class NetShieldPropertyProviderImplementation: NetShieldPropertyProvider {
    public static let netShieldNotification: Notification.Name = Notification.Name("NetShieldChangedNotification")
    @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider

    private lazy var authorizer = featureAuthorizerProvider.authorizer(forSubFeatureOf: NetShieldType.self)

    private enum StorageKey: String {
        case netShield = "NetShield"
        case lastActive = "LastActiveNetShield"
    }

    public var lastActiveNetShieldType: NetShieldType {
        guard let lastActiveType = getStoredNetShieldValue(key: .lastActive) else {
            log.warning("Last active NetShield type is nil, defaulting to \(netShieldType)")
            return netShieldType
        }

        return lastActiveType
    }
    
    public var netShieldType: NetShieldType {
        get {
            guard let value = getStoredNetShieldValue(key: .netShield) else {
                log.info("NetShield setting not found, setting to default (\(defaultNetShieldType))", category: .settings)
                self.netShieldType = defaultNetShieldType
                return defaultNetShieldType
            }
            return value
        }
        set {
            var success = false
            @Dependency(\.defaultsProvider) var provider
            success = provider
                .getDefaults()
                .setUserValue(
                    newValue.rawValue,
                    forKey: StorageKey.netShield.rawValue
                )
            if newValue != .off {
                // Duplicate active NS level, so that we can remember it to toggle it between off/on (V1 UI)
                success = provider
                    .getDefaults()
                    .setUserValue(
                        newValue.rawValue,
                        forKey: StorageKey.lastActive.rawValue
                    )
            }

            if success {
                executeOnUIThread {
                    NotificationCenter.default.post(
                        name: type(of: self).netShieldNotification,
                        object: newValue, userInfo: nil
                    )
                }
            }
        }
    }
    
    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        // Turn NetShield off on downgrade to free plan
        if tier.isFreeTier {
            netShieldType = .off
        }
        // On upgrade from the free plan, switch NetShield to the default value for the new tier
        if tier > oldTier && oldTier.isFreeTier {
            netShieldType = .level2
        }
    }

    private func getStoredNetShieldValue(key: StorageKey) -> NetShieldType? {
        @Dependency(\.defaultsProvider) var provider
        let rawValue = provider.getDefaults().userValue(forKey: key.rawValue)

        guard let intValue = rawValue as? Int else {
            log.info("Failed to retrieve stored NetShield level, stored value is either nil or not an Int: \(String(describing: rawValue))", category: .settings)
            return nil
        }

        guard let type = NetShieldType.init(rawValue: intValue) else {
            log.error("Failed to retrieve stored NetShield level, \(intValue) is not a valid NetShield type", category: .settings)
            return nil
        }

        guard authorizer(type).isAllowed else {
            log.info("User account has NetShield disabled", category: .settings)
            return defaultNetShieldType
        }

        return type
    }
    
    private var defaultNetShieldType: NetShieldType {
        authorizer(.level1) == .success ? .level1 : .off
    }

    public init() {}
}

extension NetShieldType: ModularAppFeature {
    public func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if plan.isBusiness && !plan.hasNetShield {
            return .failure(.requiresUpgrade)
        }

        if isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}

extension NetShieldType: PaidAppFeature {
    public static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if Self.level1.isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}
