//
//  UserTierProvider.swift
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

public protocol UserTierProvider {
    var currentUserTier: Int { get }
}

public protocol UserTierProviderFactory {
    func makeUserTierProvider() -> UserTierProvider
}

public class UserTierProviderImplementation: UserTierProvider {
    
    public typealias Factory = VpnKeychainFactory
    private let factory: Factory
    
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    
    public init(_ factory: Factory) {
        self.factory = factory
    }
    
    /// Tier of current user
    public var currentUserTier: Int {
        let tier = try? vpnKeychain.fetch().maxTier
        return tier ?? CoreAppConstants.VpnTiers.free
    }
    
}
