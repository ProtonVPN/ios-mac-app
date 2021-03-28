//
//  VPNLoadsRequest.swift
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

class VPNLoadsRequest: VPNBaseRequest {
    
    let ip: String?
    
    init( _ ip: String? ) {
        self.ip = ip
        super.init()
    }
    
    override func path() -> String {
        let endpoint = super.path() + "/loads"
        guard let ip = ip else {
            return endpoint
        }
        return endpoint + "?IP=\(ip)"
    }
}
