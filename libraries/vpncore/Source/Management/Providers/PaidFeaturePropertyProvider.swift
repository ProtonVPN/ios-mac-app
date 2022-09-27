//
//  Created on 07.02.2022.
//
//  Copyright (c) 2022 Proton AG
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
import VPNShared

public protocol PaidFeaturePropertyProvider: AnyObject {
    typealias Factory = PropertiesManagerFactory & UserTierProviderFactory & AuthKeychainHandleFactory & StorageFactory
    var factory: Factory { get }
    var currentUserTier: Int { get }

    init(_ factory: Factory)

    func resetForIneligibleUser()
}

extension PaidFeaturePropertyProvider {
    var propertiesManager: PropertiesManagerProtocol {
        factory.makePropertiesManager()
    }

    var authKeychainHandle: AuthKeychainHandle {
        factory.makeAuthKeychainHandle()
    }

    var userTierProvider: UserTierProvider {
        return factory.makeUserTierProvider()
    }

    public var currentUserTier: Int {
        return userTierProvider.currentUserTier
    }

    public var username: String? {
        return authKeychainHandle.fetch()?.username
    }
}
