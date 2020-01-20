//
//  HumanVerificationHandler.swift
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

public protocol HumanVerificationAdapterFactory {
    func makeHumanVerificationAdapter() -> HumanVerificationAdapter
}

public class HumanVerificationAdapter {
    var token: HumanVerificationToken?
    public init() {
    }
}

// MARK: RequestAdapter

extension HumanVerificationAdapter: RequestAdapter {
    
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let humanToken = token else { return urlRequest }
        
        var request = urlRequest
        request.addValue(humanToken.fullValue, forHTTPHeaderField: "X-PM-Human-Verification-Token")
        request.addValue(humanToken.type.rawValue, forHTTPHeaderField: "X-PM-Human-Verification-Token-Type")
        return request
    }
}
