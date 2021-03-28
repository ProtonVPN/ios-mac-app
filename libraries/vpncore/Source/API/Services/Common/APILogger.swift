//
//  APILogger.swift
//  vpncore - Created on 2020-06-15.
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

import Foundation
import Alamofire

final class APILogger: EventMonitor {
        
    /// Event called when a final `URLRequest` is created for a `Request`.
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        PMLog.D("Request started: \(request) ".cleanedForLog, level: .debug)
    }
      
    /// Event called when a `DataRequest` calls a `ResponseSerializer` and creates a generic `DataResponse<Value, AFError>`.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        let internalCode = (response.value as? NSDictionary)?.value(forKey: "Code")
        PMLog.D("Request finished: \(request); Internal response code: \(internalCode ?? "n/a");".cleanedForLog, level: .debug)
    }
    
}
