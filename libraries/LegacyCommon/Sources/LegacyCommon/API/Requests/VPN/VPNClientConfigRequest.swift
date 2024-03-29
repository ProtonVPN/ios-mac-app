//
//  VPNClientConfigRequest.swift
//  vpncore - Created on 30/04/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import ProtonCoreNetworking

final class VPNClientConfigRequest: Request {

    let isAuth: Bool
    let ip: String?

    var path: String {
        return "/vpn/v2/clientconfig"
    }

    var header: [String: Any] {
        guard let ip = ip else {
            return [:]
        }

        return ["x-pm-netzone": ip]
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }

    public init(isAuth: Bool, ip: String?) {
        self.isAuth = isAuth
        self.ip = ip
    }
}
