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
import vpncore

class AppLaunchRoutine {
    
    static var launchedBefore = true
    
    static func execute() {
        if !Storage.userDefaults().bool(forKey: AppConstants.UserDefaults.launchedBefore) {
            launchedBefore = false
            Storage.userDefaults().set(false, forKey: AppConstants.UserDefaults.startOnBoot)
            Storage.userDefaults().set(false, forKey: AppConstants.UserDefaults.startMinimized)
            PropertiesManager().hasConnected = false
            Storage.userDefaults().set(true, forKey: AppConstants.UserDefaults.systemNotifications)
            Storage.userDefaults().set(true, forKey: AppConstants.UserDefaults.launchedBefore)
        }
    }
}
