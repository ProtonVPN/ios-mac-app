//
//  NetShieldPropertyProvider.swift
//  vpncore - Created on 2021-01-06.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import VPNShared
import LocalFeatureFlags

public protocol NetShieldPropertyProvider: PaidFeaturePropertyProvider {
    /// Current NetShield type
    var netShieldType: NetShieldType { get set }

    /// Last active NetShield type
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
    private let key = "NetShield"
    private let lastActiveKey = "LastActiveNetShield"

    public required init(_ factory: Factory) {
        self.factory = factory
        self.storage = factory.makeStorage()
    }

    public var lastActiveNetShieldType: NetShieldType {
        getNetShieldValue(key: lastActiveKey)
    }
    
    public var netShieldType: NetShieldType {
        get {
            getNetShieldValue(key: key)
        }
        set {
            guard let username = username else {
                return
            }

            storage.setValue(newValue.rawValue, forKey: key + username)
            if newValue != .off {
                storage.setValue(newValue.rawValue, forKey: lastActiveKey + username)
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
        // On upgrade from a free plan, switch NetShield to the default value for the new tier
        if tier > oldTier && oldTier <= CoreAppConstants.VpnTiers.free {
            netShieldType = Self.defaultNetShieldType(for: tier)
        }
    }

    private func getNetShieldValue(key: String) -> NetShieldType {
        guard let username = username else {
            return defaultNetShieldType
        }

        guard let current = storage.defaults.value(forKey: key + username) as? Int,
                let type = NetShieldType.init(rawValue: current) else {
            return defaultNetShieldType
        }

        if type.isUserTierTooLow(currentUserTier) {
            return defaultNetShieldType
        }

        return type
    }
    
    private var defaultNetShieldType: NetShieldType {
        Self.defaultNetShieldType(for: currentUserTier)
    }

    private static func defaultNetShieldType(for userTier: Int) -> NetShieldType {
        // Select default value: off for free users, f1 for paying users.
        if userTier <= CoreAppConstants.VpnTiers.free {
            return .off
        }
        return .level1
    }
}
