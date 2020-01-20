//
//  UserApiServiceMock.swift
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

class UserApiServiceMock: UserApiService {
    
    var callbackverificationCodeRequest: ((HumanVerificationToken.TokenType, (() -> Void), ((Error) -> Void)) -> Void)?
    var callbackverificationMethodsAvailableRequest: ((((VerificationMethods) -> Void), ((Error) -> Void)) -> Void)?
    var callbackverifyCode: ((HumanVerificationToken, (() -> Void), ((Error) -> Void)) -> Void)?
    var callbackcheckAvailability: ((String, (() -> Void), ((Error) -> Void)) -> Void)?
    var callbackcreateUser: ((UserProperties, (() -> Void), ((Error) -> Void)) -> Void)?
    
    // MARK: Implemenetation
    
    func verificationCodeRequest(tokenType: HumanVerificationToken.TokenType, receiverAddress: String, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        callbackverificationCodeRequest?(tokenType, success, failure)
    }
    
    func verificationMethodsAvailableRequest(success: @escaping ((VerificationMethods) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackverificationMethodsAvailableRequest?(success, failure)
    }
    
    func verifyCode(token: HumanVerificationToken, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        callbackverifyCode?(token, success, failure)
    }
    
    func checkAvailability(username: String, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        callbackcheckAvailability?(username, success, failure)
    }
    
    func createUser(userProperties: UserProperties, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        callbackcreateUser?(userProperties, success, failure)
    }
    
}
