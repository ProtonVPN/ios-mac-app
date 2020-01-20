//
//  AuthRouter.swift
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
import Alamofire

public enum AuthRouter: Router {
    
    case authInfo(String)
    case auth(AuthenticationProperties)
    case modulus
    case refreshAccessToken(RefreshAccessTokenProperties)
    
    public var path: String {
        let base = ApiConstants.baseURL
        switch self {
        case .authInfo:
            return base + "/auth/info"
        case .auth:
            return base + "/auth"
        case .modulus:
            return base + "/auth/modulus"
        case .refreshAccessToken:
            return base + "/auth/refresh"
        }
    }
    
    public var version: String {
        switch self {
        case .auth, .authInfo, .modulus, .refreshAccessToken:
            return "3"
        }
    }
    
    public var method: HTTPMethod {
        switch self {
        case .auth, .authInfo, .refreshAccessToken:
            return .post
        case .modulus:
            return .get
        }
    }
    
    public var header: [String: String]? {
        switch self {
        case  .auth, .authInfo, .modulus:
            return nonAuthenticatedHeader
        case .refreshAccessToken:
            return expiredTokenHeader
        }
    }
    
    public var parameters: [String: Any]? {
        switch self {
        case .authInfo(let username):
            return [
                "ClientSecret": ApiConstants.clientSecret,
                "Username": username
            ]
        case .auth(let properties):
            return [
                "ClientSecret": ApiConstants.clientSecret,
                "Username": properties.username,
                "ClientEphemeral": properties.clientEphemeral,
                "ClientProof": properties.clientProof,
                "SRPSession": properties.srpSession
            ]
        case .modulus:
            return nil
        case .refreshAccessToken(let properties):
            return [
                "ResponseType": "token",
                "GrantType": "refresh_token",
                "RefreshToken": properties.refreshToken,
                "RedirectURI": "http://protonmail.ch"
            ]
        }
    }
    
    public func asURLRequest() throws -> URLRequest {
        let url = URL(string: path)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = header
        urlRequest.timeoutInterval = ApiConstants.defaultRequestTimeout
        return try parameterEncoding.encode(urlRequest, with: parameters)
    }
}
