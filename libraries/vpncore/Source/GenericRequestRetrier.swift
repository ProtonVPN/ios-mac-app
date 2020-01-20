//
//  GenericRequestRetrier.swift
//  vpncore - Created on 19/09/2019.
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

public protocol GenericRequestRetrierFactory {
    func makeGenericRequestRetrier() -> GenericRequestRetrier
}

public class GenericRequestRetrier: RequestRetrier {
    
    public init() {
    }
    
    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        let result = should(manager, retry: request, with: error)
        completion(result.0, result.1)
    }
    
    public func should(_ manager: SessionManager, retry request: Request, with error: Error) -> (Bool, TimeInterval) {
        if (error as NSError).code == (-1005), request.retryCount < 1 {
            return (true, 1.0) // retry after 1 second
        } else {
            return (false, 0.0) // don't retry
        }
    }
    
}
