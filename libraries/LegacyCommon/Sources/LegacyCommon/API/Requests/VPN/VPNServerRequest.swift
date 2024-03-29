//
//  VPNServerRequest.swift
//  vpncore - Created on 18/08/2020.
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

final class VPNServerRequest: Request {
    
    let serverId: String
    
    init( _ serverId: String) {
        self.serverId = serverId
    }
    
    var path: String {
        return "/vpn/v1/servers/" + serverId
    }

    var isAuth: Bool {
        return false
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}
