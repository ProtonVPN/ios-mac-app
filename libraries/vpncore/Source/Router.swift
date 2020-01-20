//
//  Router.swift
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

public protocol Router: URLRequestConvertible {
    
    var path: String { get }
    var version: String { get }
    var method: HTTPMethod { get }
    var header: [String: String]? { get }
    var parameters: [String: Any]? { get }
    
    var authenticatedHeader: [String: String]? { get }
    var nonAuthenticatedHeader: [String: String]? { get }
    
    var parameterEncoding: ParameterEncoding { get }
    
    func asURLRequest() throws -> URLRequest
}

public extension Router {
    
    var header: [String: String]? {
        return authenticatedHeader
    }
    
    var authenticatedHeader: [String: String]? {
        guard let authCredentials = AuthKeychain.fetch() else {
            return nonAuthenticatedHeader
        }
        return  [
            "Authorization": authCredentials.accessToken,
            "x-pm-uid": authCredentials.sessionId,
            "x-pm-appversion": ApiConstants.appVersion,
            "x-pm-apiversion": self.version,
            "Content-Type": ApiConstants.contentType,
            "Accept": ApiConstants.mediaType
        ]
    }
    
    var expiredTokenHeader: [String: String]? {
        guard let authCredentials = AuthKeychain.fetch() else {
            return nil
        }
        return  [
            "x-pm-uid": authCredentials.sessionId,
            "x-pm-appversion": ApiConstants.appVersion,
            "x-pm-apiversion": self.version,
            "Content-Type": ApiConstants.contentType,
            "Accept": ApiConstants.mediaType
        ]
    }
    
    var nonAuthenticatedHeader: [String: String]? {
        return [
            "x-pm-appversion": ApiConstants.appVersion,
            "x-pm-apiversion": self.version,
            "Content-Type": ApiConstants.contentType,
            "Accept": ApiConstants.mediaType
        ]
    }
    
    var parameters: [String: Any]? {
        return nil
    }
    
    var parameterEncoding: ParameterEncoding {
        switch method {
        case .get:
            return URLEncoding.default
        default:
            return JSONEncoding.default
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let url = URL(string: path)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = header
        urlRequest.timeoutInterval = ApiConstants.defaultRequestTimeout
        return try parameterEncoding.encode(urlRequest, with: parameters)
    }
}
