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

public protocol PaidFeaturePropertyProvider {
    typealias Factory = PropertiesManagerFactory & UserTierProviderFactory
    var factory: Factory { get }
    var propertiesManager: PropertiesManagerProtocol { get }
    var currentUserTier: Int { get }

    init(_ factory: Factory)
}

extension PaidFeaturePropertyProvider {
    var userTierProvider: UserTierProvider {
        return factory.makeUserTierProvider()
    }

    public var propertiesManager: PropertiesManagerProtocol {
        factory.makePropertiesManager()
    }

    public var currentUserTier: Int {
        return userTierProvider.currentUserTier
    }
}
