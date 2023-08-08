//
//  FirstLaunchRoutine.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import Dependencies
import LegacyCommon
import VPNShared

class AppLaunchRoutine {
    
    static var launchedBefore = true
    
    static func execute(propertiesManager: PropertiesManagerProtocol) {
        @Dependency(\.defaultsProvider) var provider
        let defaults = provider.getDefaults()
        if !defaults.bool(forKey: AppConstants.UserDefaults.launchedBefore) {
            launchedBefore = false
            defaults.set(false, forKey: AppConstants.UserDefaults.startOnBoot)
            defaults.set(false, forKey: AppConstants.UserDefaults.startMinimized)
            propertiesManager.hasConnected = false
            defaults.set(true, forKey: AppConstants.UserDefaults.systemNotifications)
            defaults.set(true, forKey: AppConstants.UserDefaults.launchedBefore)
        }
    }
}
