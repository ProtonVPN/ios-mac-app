//
//  Created on 2021-11-25.
//
//  Copyright (c) 2021 Proton AG
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

public extension PropertiesManager {
    
    func logCurrentState() {
        let keysToLog = Set(Keys.allCases).subtracting([Keys.userIp, Keys.streamingServices, Keys.servicePlans, Keys.defaultPlanDetails, Keys.streamingResourcesUrl])
        
        var message = ""
        for key in keysToLog {
            let value = Storage.userDefaults().value(forKeyPath: key.rawValue)
            message += "\n \(key)=\(value.stringForLog);"
        }
        log.info("\(message)", category: .settings, event: .current)
    }
    
}
