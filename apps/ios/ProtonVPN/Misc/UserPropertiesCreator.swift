//
//  UserPropertiesCreator.swift
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
// swiftlint:disable function_parameter_count

import vpncore

/// Creates user properties request object
protocol UserPropertiesCreator {
    func createUserProperties(email: String, username: String, password: String, modulusResponse: ModulusResponse, deviceToken: Data?, challenge: [String: Any]?) throws -> UserProperties
}

protocol UserPropertiesCreatorFactory {
    func makeUserPropertiesCreator() -> UserPropertiesCreator
}

extension DependencyContainer: UserPropertiesCreatorFactory {
    func makeUserPropertiesCreator() -> UserPropertiesCreator {
        return UserPropertiesCreatorImplementation()
    }
}

final class UserPropertiesCreatorImplementation: UserPropertiesCreator {
    func createUserProperties(email: String, username: String, password: String, modulusResponse: ModulusResponse, deviceToken: Data?, challenge: [String: Any]?) throws -> UserProperties {
        guard let salt: Data = try SrpRandomBits(80) else { // needs to be set to 80 bits for login password
            throw ApplicationError.userCreation
        }
        
        guard let auth = try SrpAuthForVerifier(password, modulusResponse.modulus, salt) else {
            throw ApplicationError.userCreation
        }
        let verifier = try auth.generateVerifier(2048)
                    
        let userProperties = UserProperties(email: email, username: username, modulusID: modulusResponse.modulusId, salt: salt.encodeBase64(), verifier: verifier.encodeBase64(), appleToken: deviceToken, challenge: challenge)
        return userProperties
    }
    
}
