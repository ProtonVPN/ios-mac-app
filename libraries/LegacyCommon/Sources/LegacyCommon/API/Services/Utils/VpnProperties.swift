//
//  VpnProperties.swift
//  vpncore - Created on 06/05/2020.
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

import Foundation
import ProtonCoreDataModel

public struct VpnProperties {
    
    public let serverModels: [ServerModel]
    public let vpnCredentials: VpnCredentials
    public let location: UserLocation?
    public let clientConfig: ClientConfig?
    public let userRole: UserRole
    public let userCreateTime: Date?
    public let userAccountRecovery: AccountRecovery?

    public init(serverModels: [ServerModel], vpnCredentials: VpnCredentials, location: UserLocation?, clientConfig: ClientConfig?, user: User?) {
        self.serverModels = serverModels
        self.vpnCredentials = vpnCredentials
        self.location = location
        self.clientConfig = clientConfig
        self.userRole = .init(rawValue: user?.role ?? 0) ?? .noOrganization
        self.userAccountRecovery = user?.accountRecovery

        if let createTime = user?.createTime {
            self.userCreateTime = Date(timeIntervalSince1970: createTime)
        } else {
            self.userCreateTime = nil
        }
    }
}
