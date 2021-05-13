//
//  UserAPI.swift
//  PMNetworking
//
//  Created by on 5/25/20.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

// Users API
// Doc: https://github.com/ProtonMail/Slim-API/blob/develop/api-spec/pm_api_users.md

public class HumanVerifyAPI: APIClient {

    static let route: String = "/users"

    public enum Router: Request {
        case code(type: HumanVerificationToken.TokenType, receiver: String)
        case check(token: HumanVerificationToken)
        case checkUsername(String)
        case createUser(UserProperties)
        case userInfo

        public var path: String {
            switch self {
            case .code:
                return route + "/code"
            case .check:
                return route + "/check"
            case .checkUsername(let username):
                return route + "/available?Name=" + username.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            case .createUser:
                return route
            case .userInfo:
                return route
            }
        }

        public var isAuth: Bool {
            switch self {
            case .code, .check, .userInfo:
                return true
            default:
                return false
            }
        }

        public var header: [String: Any] {
            return [:]
        }

        public var apiVersion: Int {
            switch self {
            case .code, .check, .checkUsername, .createUser, .userInfo:
                return 3
            }
        }

        public var method: HTTPMethod {
            switch self {
            case .checkUsername, .userInfo:
                return .get
            case  .code, .createUser:
                return .post
            case .check:
                return .put
            }
        }

        public var parameters: [String: Any]? {
            switch self {
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
                    "Type": "1"
                ]
            case .createUser(let userProperties):
                var params: [String: Any] = [
                    "Email": userProperties.email,
                    "Username": userProperties.username,
                    "Type": "1",
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
            default:
                return [:]
            }
        }
    }
}
