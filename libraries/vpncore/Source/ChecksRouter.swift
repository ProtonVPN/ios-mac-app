//
//  ChecksRouter.swift
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

enum ChecksRouter: Router {
    
    case status
    
    var path: String {
        switch self {
        case .status:
            return ApiConstants.statusURL + "/vpn_status"
        }
    }
    
    var version: String {
        switch self {
        case .status:
            return "1"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .status:
            return .get
        }
    }
    
    var header: [String: String]? {
        switch self {
        case .status:
            return [:]
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let url = URL(string: path)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = header
        urlRequest.cachePolicy = .reloadIgnoringCacheData
        urlRequest.timeoutInterval = ApiConstants.defaultRequestTimeout
        return urlRequest
    }
}
