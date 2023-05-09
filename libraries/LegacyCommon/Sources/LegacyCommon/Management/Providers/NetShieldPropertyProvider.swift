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
import VPNShared
import LocalFeatureFlags

public protocol NetShieldPropertyProvider: PaidFeaturePropertyProvider {
    /// Current NetShield type
    var netShieldType: NetShieldType { get set }

    /// Used to store last non-off NS level when toggling NS off <-> on in NS V1 UI
    var lastActiveNetShieldType: NetShieldType { get }

    /// Check if current user can use NetShield
    var isUserEligibleForNetShield: Bool { get }

    static var netShieldNotification: Notification.Name { get }
}

public protocol NetShieldPropertyProviderFactory {
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider
}

public class NetShieldPropertyProviderImplementation: NetShieldPropertyProvider {
    public let factory: Factory

    public static let netShieldNotification: Notification.Name = Notification.Name("NetShieldChangedNotification")

    private let storage: Storage

    private enum StorageKey: String {
        case netShield = "NetShield"
        case lastActive = "LastActiveNetShield"
    }

    public required init(_ factory: Factory) {
        self.factory = factory
        self.storage = factory.makeStorage()
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
            guard let username = username else {
                log.error("Unable to update stored NetShield level, username is nil", category: .settings)
                return
            }

            storage.setValue(newValue.rawValue, forKey: StorageKey.netShield.rawValue + username)
            if newValue != .off {
                // Duplicate active NS level, so that we can remember it to toggle it between off/on (V1 UI)
                storage.setValue(newValue.rawValue, forKey: StorageKey.lastActive.rawValue + username)
            }

            executeOnUIThread {
                NotificationCenter.default.post(name: type(of: self).netShieldNotification, object: newValue, userInfo: nil)
            }
        }
    }
    
    public var isUserEligibleForNetShield: Bool {
        var types = NetShieldType.allCases
        types.removeAll { $0 == .off }
        
        for type in types {
            if !type.isUserTierTooLow(currentUserTier) {
                return true
            }
        }
        return false
    }

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        // Turn NetShield off on downgrade to free plan
        if tier <= CoreAppConstants.VpnTiers.free {
            netShieldType = .off
        }
        // On upgrade from the free plan, switch NetShield to the default value for the new tier
        if tier > oldTier && oldTier <= CoreAppConstants.VpnTiers.free {
            netShieldType = Self.defaultNetShieldType(for: tier)
        }
    }

    private func getStoredNetShieldValue(key: StorageKey) -> NetShieldType? {
        guard let username = username else {
            log.error("Failed to retrieve stored NetShield level, username is nil", category: .settings)
            return nil
        }

        let rawValue = storage.defaults.value(forKey: key.rawValue + username)
        guard let intValue = rawValue as? Int else {
            log.info("Failed to retrieve stored NetShield level, stored value is either nil or not an Int: \(String(describing: rawValue))", category: .settings)
            return nil
        }

        guard let type = NetShieldType.init(rawValue: intValue) else {
            log.error("Failed to retrieve stored NetShield level, \(intValue) is not a valid NetShield type", category: .settings)
            return nil
        }

        if type.isUserTierTooLow(currentUserTier) {
            log.info("User tier \(currentUserTier) is not high enough for stored NS level \(type), returning default (\(defaultNetShieldType))", category: .settings)
            return defaultNetShieldType
        }

        return type
    }
    
    private var defaultNetShieldType: NetShieldType {
        Self.defaultNetShieldType(for: currentUserTier)
    }

    private static func defaultNetShieldType(for userTier: Int) -> NetShieldType {
        // Select default value: off for free users, level2 for paying users.
        if userTier <= CoreAppConstants.VpnTiers.free {
            return .off
        }
        return .level2
    }
}
