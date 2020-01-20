//
//  VpnRouter.swift
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

enum VpnRouter: Router {
    
    case clientCredentials
    case logicalServices(ip: String?)
    case location
    case sessions
    case loads
    
    var path: String {
        let base = ApiConstants.baseURL
        switch self {
        case .clientCredentials:
            return base + "/vpn"
        case .logicalServices(let ip):
            let endpoint = base + "/vpn/logicals"
            guard let ip = ip else {
                return endpoint
            }
            return endpoint + "?IP=\(ip)"
        case .location:
            return base + "/vpn/location"
        case .sessions:
            return base + "/vpn/sessions"
        case .loads:
            return base + "/vpn/loads"
        }
    }
    
    var version: String {
        switch self {
        case .clientCredentials, .logicalServices, .location, .sessions, .loads:
            return "3"
        }
    }
    
    var method: Alamofire.HTTPMethod {
        switch self {
        case .clientCredentials, .logicalServices, .location, .sessions, .loads:
            return .get
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        guard let header = header else {
            let error = KeychainError.fetchFailure
            PMLog.ET("Error during header creation: \(error.localizedDescription)")
            throw error
        }
        
        let url = URL(string: path)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.allHTTPHeaderFields = header
        switch self {
        case .sessions:
            urlRequest.timeoutInterval = 15 // allows the timeout on vpn connections to remain at a total of 30s
        default:
            urlRequest.timeoutInterval = ApiConstants.defaultRequestTimeout
        }
        return urlRequest
    }
}
