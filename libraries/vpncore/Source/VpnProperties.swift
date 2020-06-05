//
//  VpnProperties.swift
//  vpncore - Created on 06/05/2020.
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

public struct VpnProperties {
    
    public let serverModels: [ServerModel]
    public let vpnCredentials: VpnCredentials?
    public let ip: String?
    public let openVpnConfig: OpenVpnConfig
    
    public init(serverModels: [ServerModel], vpnCredentials: VpnCredentials?, sessionModels: [SessionModel]?, ip: String?, openVpnConfig: OpenVpnConfig, appStateManager: AppStateManager?) {
        self.serverModels = serverModels
        self.vpnCredentials = vpnCredentials
        self.ip = ip
        self.openVpnConfig = openVpnConfig
        
        guard let sessionModels = sessionModels else {
            return
        }
        
        let ikeSessions = sessionModels.filter { session -> Bool in
            session.vpnProtocol == .ikev2
        }
        
        let connectedIp = appStateManager?.activeConnection()?.serverIp.exitIp
        
        self.serverModels.forEach { server in
            server.ips.forEach { ip in
                ip.hasExistingSession = false
                ikeSessions.forEach { session in
                    if ip.exitIp == session.exitIp {
                        if let connectedIp = connectedIp, connectedIp == ip.exitIp {
                        } else {
                            ip.hasExistingSession = true
                        }
                    }
                }
            }
        }
    }
}
