//
//  UserPropertiesCreatorMock.swift
//  ProtonVPN - Created on 15/10/2019.
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

class UserPropertiesCreatorMock: UserPropertiesCreator {
        
    func createUserProperties(email: String, username: String, password: String, modulusResponse: ModulusResponse, deviceToken: Data?) throws -> UserProperties {
        return UserProperties(email: email, username: username, modulusID: modulusResponse.modulusId, salt: "salt", verifier: "verifier", appleToken: deviceToken)
    }
    
}
