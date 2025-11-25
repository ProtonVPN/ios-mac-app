//
//  Created on 04/07/2023.
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

import Dependencies
import Foundation
import VPNAppCore

public extension SettingsStorageKey {
    static var userDefaults: SettingsStorage {
        SettingsStorage(
            getConnectionProtocol: {
                @Dependency(\.propertiesManager) var propertiesManager
                return propertiesManager.connectionProtocol
            },
            setConnectionProtocol: {
                @Dependency(\.propertiesManager) var propertiesManager
                return propertiesManager.connectionProtocol = $0
            },
            getNetShield: {
                @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
                return netShieldPropertyProvider.getNetShieldType()
            },
            setNetShield: {
                @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
                netShieldPropertyProvider.setNetShieldType($0)
            }
        )
    }
}
