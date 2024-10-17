//
//  Created on 17/10/24.
//
//  Copyright (c) 2024 Proton AG
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

import UITestsHelpers
import Foundation

public enum BF22Users {
    case plusUser
    case cycle15User
    case cycle30User
    case freeUser
    
    public var credentials: Credentials {
        let allCredentials = getCredentials(fromResource: "credentials_bf22")
        switch self {
        case .plusUser:
            return allCredentials[0]
        case .cycle15User:
            return allCredentials[1]
        case .cycle30User:
            return allCredentials[2]
        case .freeUser:
            return allCredentials[3]
        }
    }
    
    // Sample function to get credentials from a resource
    func getCredentials(fromResource resource: String) -> [Credentials] {
        return Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: resource, withExtension: "plist")!)
    }
}
