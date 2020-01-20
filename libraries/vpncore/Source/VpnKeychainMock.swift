//
//  VpnKeychainMock.swift
//  vpncore - Created on 26.06.19.
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

public class VpnKeychainMock: VpnKeychainProtocol {
    
    public static var vpnCredentialsChanged = Notification.Name("")
    
    private var credentials: VpnCredentials
    
    public init(accountPlan: AccountPlan = .free, maxTier: Int = 0) {
        credentials = VpnKeychainMock.vpnCredentials(accountPlan: accountPlan, maxTier: maxTier)
    }
    
    public func fetch() throws -> VpnCredentials {
        return credentials
    }
    
    public func fetchOpenVpnPassword() throws -> Data {
        return Data()
    }
    
    public func store(vpnCredentials: VpnCredentials) {}
    public func clear() {}
    
    public func setVpnCredentials(with accountPlan: AccountPlan, maxTier: Int = 0) {
        credentials = VpnKeychainMock.vpnCredentials(accountPlan: accountPlan, maxTier: maxTier)
    }
    
    private static func vpnCredentials(accountPlan: AccountPlan, maxTier: Int) -> VpnCredentials {
        return VpnCredentials(
            status: 0,
            expirationTime: Date(),
            accountPlan: accountPlan,
            maxConnect: 1,
            maxTier: maxTier,
            services: 0,
            groupId: "grid1",
            name: "username",
            password: "",
            delinquent: 0
        )
    }
    
    public func hasOldVpnPassword() -> Bool {
        return false
    }
    
    public func clearOldVpnPassword() throws {
    }
    
}
