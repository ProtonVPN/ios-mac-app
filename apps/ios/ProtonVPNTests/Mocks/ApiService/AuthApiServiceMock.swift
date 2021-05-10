//
//  AuthApiServiceMock.swift
//  ProtonVPN - Created on 13/09/2019.
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

class AuthApiServiceMock: AuthApiService {
    
    var callbackauthenticate: ((String, String, ((AuthCredentials) -> Void), ((Error) -> Void)) -> Void)?
    var callbackmodulus: ((((ModulusResponse) -> Void), ((Error) -> Void)) -> Void)?
    var callbackRefreshAccessToken: ((((AuthCredentials) -> Void), ((Error) -> Void)) -> Void)?
    
    // MARK: Implementation
    
    func authenticate(username: String, password: String, success: @escaping (AuthCredentials) -> Void, failure: @escaping (Error) -> Void) {
        callbackauthenticate?(username, password, success, failure)
    }
    
    func modulus(success: @escaping ((ModulusResponse) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackmodulus?(success, failure)
    }
    
    func refreshAccessToken(success: @escaping AuthCredentialsCallback, failure: @escaping ErrorCallback) {
        callbackRefreshAccessToken?(success, failure)
    }
    
}
