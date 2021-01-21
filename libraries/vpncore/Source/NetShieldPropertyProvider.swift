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

public protocol NetShieldPropertyProvider {
    /// Current NetShield type
    var netShieldType: NetShieldType { get set }
    /// Check if current user can use NetShield
    var isUserEligibleForNetShield: Bool { get }
}

public protocol NetShieldPropertyProviderFactory {
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider
}

public class NetShieldPropertyProviderImplementation: NetShieldPropertyProvider {
    
    public typealias Factory = PropertiesManagerFactory & UserTierProviderFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var userTierProvider: UserTierProvider = factory.makeUserTierProvider()
    
    public init(_ factory: Factory) {
        self.factory = factory
    }
    
    public var netShieldType: NetShieldType {
        get {
            guard let type = propertiesManager.netShieldType else {
                return defaultNetShieldType
            }
            if type.isUserTierTooLow(currentUserTier) {
                return defaultNetShieldType
            }
            return type
        }
        set {
            propertiesManager.netShieldType = newValue
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
    
    private var currentUserTier: Int {
        return userTierProvider.currentUserTier
    }
    
    private var defaultNetShieldType: NetShieldType {
        // Select default value: off for free users, f1 for paying users.
        if currentUserTier <= CoreAppConstants.VpnTiers.free {
            return .off
        }
        return .level1
    }
}
