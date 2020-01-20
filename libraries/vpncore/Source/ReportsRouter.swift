//
//  ReportsRouter.swift
//  vpncore - Created on 01/07/2019.
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

enum ReportsRouter: Router {
    
    case bug(ReportBug)
    
    var path: String {
        switch self {
        case .bug:
            return ApiConstants.baseURL + "/reports/bug"
        }
    }
    
    var version: String {
        switch self {
        case .bug:
            return "3"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .bug:
            return .post
        }
    }
    
    var parameters: [String: String]? {
        switch self {
        case .bug(let bug):
            return [
                "OS": bug.os,
                "OSVersion": bug.osVersion,
                "Client": bug.client,
                "ClientVersion": bug.clientVersion,
                "ClientType": String(bug.clientType),
                "Title": bug.title,
                "Description": bug.description,
                "Username": bug.username,
                "Email": bug.email,
                "Country": bug.country,
                "ISP": bug.ISP,
                "Plan": bug.plan
            ]
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
