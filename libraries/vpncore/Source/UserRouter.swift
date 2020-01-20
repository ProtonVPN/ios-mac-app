//
//  CreateUserRouter.swift
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

import Alamofire
import Foundation

private let vpnType = 2

enum UserRouter: Router {
    
    case code(type: HumanVerificationToken.TokenType, receiver: String)
    case check(token: HumanVerificationToken)
    case checkUsername(String)
    case createUser(UserProperties)
    
    var path: String {
        let base = ApiConstants.baseURL
        switch self {
        case .code:
            return base + "/users/code"
        case .check:
            return base + "/users/check"
        case .checkUsername(let username):
            return base + "/users/available?Name=" + username.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        case .createUser:
            return base + "/users"
        }
    }
    
    var version: String {
        switch self {
        case .code, .check, .checkUsername, .createUser:
            return "3"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .checkUsername:
            return .get
        case  .code, .createUser:
            return .post
        case .check:
            return .put
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .checkUsername:
            return nil
        case .code(let type, let receiver):
            let destinationType: String
            switch type {
            case .email:
                destinationType = "Address"
            case .sms:
                destinationType = "Phone"
            case .payment, .invite, .captcha:
                fatalError("Wrong parameter used. Payment is not supported by code endpoint.")
            }
            return [
                "Type": type.rawValue,
                "Destination": [
                    destinationType: receiver
                ]
            ]
        case .check(let token):
            return [
                "Token": "\(token.fullValue)",
                "TokenType": token.type.rawValue,
                "Type": vpnType
            ]
        case .createUser(let userProperties):
            var params: [String: Any] = [
                "Email": userProperties.email,
                "Username": userProperties.username,
                "Type": vpnType,
                "Auth": [
                    "Version": 4,
                    "ModulusID": userProperties.modulusID,
                    "Salt": userProperties.salt,
                    "Verifier": userProperties.verifier
                ]
            ]
            if let token = userProperties.appleToken {
                params["Payload"] = [
                    "higgs-boson": token.base64EncodedString()
                ]
            }
            return params
        }
    }
}
