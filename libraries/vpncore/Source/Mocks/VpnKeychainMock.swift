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
@testable import vpncore

public class VpnKeychainMock: VpnKeychainProtocol {
    
    public enum KeychainMockError: Error {
        case fetchError
        case getCertificateError
    }
    
    public var throwsOnFetch: Bool = false
    
    public static var vpnCredentialsChanged = Notification.Name("")
    public static var vpnPlanChanged = Notification.Name("")
    public static var vpnMaxDevicesReached = Notification.Name("")
    public static var vpnUserDelinquent = Notification.Name("")
    
    private var credentials: VpnCredentials
    
    public init(accountPlan: AccountPlan = .free, maxTier: Int = 0) {
        credentials = VpnKeychainMock.vpnCredentials(accountPlan: accountPlan, maxTier: maxTier)
    }
    
    public func fetch() throws -> VpnCredentials {
        if throwsOnFetch {
            throw KeychainMockError.fetchError
        }
        return credentials
    }
    
    public func fetchOpenVpnPassword() throws -> Data {
        return Data()
    }
    
    public func store(vpnCredentials: VpnCredentials) {}
    
    public func getServerCertificate() throws -> SecCertificate {
        throw KeychainMockError.getCertificateError
    }
    
    public func storeServerCertificate() throws {}
    
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
            delinquent: 0,
            credit: 0,
            currency: "",
            hasPaymentMethod: false,
            planName: accountPlan.rawValue
        )
    }
    
    public func hasOldVpnPassword() -> Bool {
        return false
    }
    
    public func clearOldVpnPassword() throws {
    }
    
    public func store(wireguardConfiguration: String) throws -> Data {
        return Data()
    }
    
    public func fetchWireguardConfigurationReference() throws -> Data {
        return Data()
    }
    
    public func fetchWireguardConfiguration() throws -> String? {
        return nil
    }
    
}
