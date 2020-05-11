//
//  BaseRequest.swift
//  vpncore - Created on 30/04/2020.
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
//

import Alamofire

class BaseRequest: URLRequestConvertible {
    
    //MARK: - Override
    
    func path() -> String {
        return ApiConstants.baseURL
    }
    
    //MARK: - Computed
    
    var version: String {
        return "3"
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var header: [String: String]? {
        return authenticatedHeader
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
    
    //MARK: - URLRequestConvertible
    
    func asURLRequest() throws -> URLRequest {
        let url = URL(string: path())!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = header
        urlRequest.timeoutInterval = ApiConstants.defaultRequestTimeout
        return try parameterEncoding.encode(urlRequest, with: parameters)
    }
}

extension BaseRequest {
    
    var nonAuthenticatedHeader: [String: String]? {  return defaultHeader }

    var authenticatedHeader: [String: String]? {
        guard let authCredentials = AuthKeychain.fetch() else {
            return nonAuthenticatedHeader
        }
        return defaultHeader + [
            "Authorization": "Bearer \(authCredentials.accessToken)",
            "x-pm-uid": authCredentials.sessionId
        ]
    }
    
    var expiredTokenHeader: [String: String]? {
        guard let authCredentials = AuthKeychain.fetch() else {
            return defaultHeader
        }
        return defaultHeader + [
            "x-pm-uid": authCredentials.sessionId
        ]
    }
    
    //MARK: - Private
    
    private var defaultHeader: [String: String] {
        return [
            "x-pm-appversion": ApiConstants.appVersion,
            "x-pm-apiversion": self.version,
            "Content-Type": ApiConstants.contentType,
            "Accept": ApiConstants.mediaType,
            "User-Agent": ApiConstants.userAgent
        ]
    }
}
