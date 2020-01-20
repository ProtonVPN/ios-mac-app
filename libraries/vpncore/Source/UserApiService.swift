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

public struct HumanVerificationToken {
    let type: TokenType
    let token: String
    let input: String? // Email, phone number or catcha token
    
    public init(type: TokenType, token: String, input: String? = nil) {
        self.type = type
        self.token = token
        self.input = input
    }
    
    var fullValue: String {
        switch type {
        case .email, .sms:
            return "\(input ?? ""):\(token)"
        case .payment, .captcha:
            return token
        case .invite:
            return ""
        }
    }
    
    public enum TokenType: String, CaseIterable {
        case email
        case sms
        case invite
        case payment
        case captcha
        //    case coupon // Since this isn't compatible with IAP, this option can be safely ignored
        
        static func type(fromString: String) -> TokenType? {
            for value in TokenType.allCases where value.rawValue == fromString {
                return value
            }
            return nil
        }
    }
    
}

public struct UserProperties {
    
    public let email: String
    public let username: String
    public let modulusID: String
    public let salt: String
    public let verifier: String
    public let appleToken: Data?
    
    public var description: String {
        return
            "Username: \(username)\n" +
            "ModulusID: \(modulusID)\n" +
            "Salt: \(salt)\n" +
            "Verifier: \(verifier)\n" +
            "HasAppleToken: \(appleToken == nil ? "No" : "Yes")\n"
    }
    
    public init(email: String, username: String, modulusID: String, salt: String, verifier: String, appleToken: Data?) {
        self.email = email
        self.username = username
        self.modulusID = modulusID
        self.salt = salt
        self.verifier = verifier
        self.appleToken = appleToken
    }
}

public protocol UserApiServiceFactory {
    func makeUserApiService() -> UserApiService
}

public protocol UserApiService {
    func verificationCodeRequest(tokenType: HumanVerificationToken.TokenType,
                                 receiverAddress: String,
                                 success: @escaping (() -> Void),
                                 failure: @escaping ((Error) -> Void))
    func verifyCode(token: HumanVerificationToken,
                    success: @escaping (() -> Void),
                    failure: @escaping ((Error) -> Void))
    func checkAvailability(username: String,
                           success: @escaping (() -> Void),
                           failure: @escaping ((Error) -> Void))
    func createUser(userProperties: UserProperties,
                    success: @escaping (() -> Void),
                    failure: @escaping ((Error) -> Void))
}

public class UserApiServiceImplementation: UserApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    public func verificationCodeRequest(tokenType: HumanVerificationToken.TokenType,
                                        receiverAddress: String,
                                        success: @escaping (() -> Void),
                                        failure: @escaping ((Error) -> Void)) {
        alamofireWrapper.request(UserRouter.code(type: tokenType, receiver: receiverAddress), success: success, failure: failure)
    }
        
    public func verifyCode(token: HumanVerificationToken,
                           success: @escaping (() -> Void),
                           failure: @escaping ((Error) -> Void)) {
        alamofireWrapper.request(UserRouter.check(token: token), success: success, failure: failure)
    }
    
    public func checkAvailability(username: String,
                                  success: @escaping (() -> Void),
                                  failure: @escaping ((Error) -> Void)) {
        alamofireWrapper.request(UserRouter.checkUsername(username), success: success, failure: failure)
    }
    
    public func createUser(userProperties: UserProperties,
                           success: @escaping (() -> Void),
                           failure: @escaping ((Error) -> Void)) {
        alamofireWrapper.request(UserRouter.createUser(userProperties), success: success, failure: failure)
    }
}
