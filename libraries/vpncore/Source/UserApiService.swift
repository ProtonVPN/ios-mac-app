//
//  CreateUserApiService.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public typealias HumanTokenType = HumanVerificationToken.TokenType

public protocol UserApiServiceFactory {
    func makeUserApiService() -> UserApiService
}

public protocol UserApiService {
    func verificationCodeRequest(tokenType: HumanTokenType, receiverAddress: String, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
    
    func verifyCode(token: HumanVerificationToken, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
    
    func checkAvailability(username: String, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
    
    func createUser(userProperties: UserProperties, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
}

public class UserApiServiceImplementation: UserApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    public func verificationCodeRequest(tokenType: HumanTokenType, receiverAddress: String, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        alamofireWrapper.request(UserCodeRequest(tokenType, receiver: receiverAddress), success: success, failure: failure)
    }
    
    public func verifyCode(token: HumanVerificationToken, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        alamofireWrapper.request(UserCheckRequest(token), success: success, failure: failure)
    }
    
    public func checkAvailability(username: String, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        alamofireWrapper.request(UserCheckUsernameRequest(username), success: success, failure: failure)
    }
    
    public func createUser(userProperties: UserProperties, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        alamofireWrapper.request(UserCreateRequest(userProperties), success: success, failure: failure)
    }
}
