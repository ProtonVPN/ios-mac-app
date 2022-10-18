//
//  VPNLocationRequest.swift
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

import ProtonCore_Networking
import VPNShared

final class VPNLocationRequest: Request {
    var path: String {
        return "/vpn/location"
    }

    var isAuth: Bool {
        return false
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

public struct UserLocation: Codable {
    public let ip: String
    public let country: String
    public let isp: String

    public init(dic: VPNShared.JSONDictionary) throws {
        ip = try dic.stringOrThrow(key: "IP")
        country = try dic.stringOrThrow(key: "Country")
        isp = try dic.stringOrThrow(key: "ISP")
    }
}
