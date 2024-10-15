//
//  Created on 22/8/24.
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

import Foundation

public enum UserType {
    case Free
    case Basic
    case Plus
    
    public var credentials: Credentials {
        let allCredentials = getCredentials(fromResource: "credentials")
        switch self {
        case .Free:
            return allCredentials[0]
        case .Basic:
            return allCredentials[1]
        case .Plus:
            return allCredentials[2]
        }
    }
    
    // Sample function to get credentials from a resource
    func getCredentials(fromResource resource: String) -> [Credentials] {
        return Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: resource, withExtension: "plist")!)
    }
}
