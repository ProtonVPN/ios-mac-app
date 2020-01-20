//
//  VpnKeychain.swift
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
import KeychainAccess

public protocol VpnKeychainProtocol {
    
    static var vpnCredentialsChanged: Notification.Name { get }
    
    func fetch() throws -> VpnCredentials
    func fetchOpenVpnPassword() throws -> Data
    func store(vpnCredentials: VpnCredentials)
    func clear()
    
    // Dealing with old vpn password entry.
    // These can be deleted after all users have iOS version > 1.3.2 and MacOs app version > 1.5.5
    func hasOldVpnPassword() -> Bool
    func clearOldVpnPassword() throws
}

public protocol VpnKeychainFactory {
    func makeVpnKeychain() -> VpnKeychainProtocol
}

public class VpnKeychain: VpnKeychainProtocol {
    
    private struct StorageKey {
        static let vpnCredentials = "vpnCredentials"
        static let openVpnPassword_old = "openVpnPassword"
        static let vpnServerPassword = "ProtonVPN-Server-Password"
    }
    
    private let appKeychain = Keychain(service: CoreAppConstants.appKeychain).accessibility(.afterFirstUnlockThisDeviceOnly)
    
    public static let vpnCredentialsChanged = Notification.Name("VpnKeychainCredentialsChanged")
    
    public init() {}
    
    public func fetch() throws -> VpnCredentials {
        if let data = appKeychain[data: StorageKey.vpnCredentials] {
            if let vpnCredentials = NSKeyedUnarchiver.unarchiveObject(with: data) as? VpnCredentials {
                return vpnCredentials
            }
        }
        
        let error = ProtonVpnErrorConst.vpnCredentialsMissing
        PMLog.D(error.localizedDescription, level: .error)
        throw error
    }
    
    public func fetchOpenVpnPassword() throws -> Data {
        do {
            let password = try getPasswordRefference()
            return password
        } catch let error {
            PMLog.D(error.localizedDescription, level: .error)
            throw ProtonVpnErrorConst.vpnCredentialsMissing
        }
    }
    
    public func store(vpnCredentials: VpnCredentials) {
        appKeychain[data: StorageKey.vpnCredentials] = NSKeyedArchiver.archivedData(withRootObject: vpnCredentials)
        do {
            try setPassword(vpnCredentials.password)
        } catch let error {
            PMLog.ET("Error occurred during OpenVPN password storage: \(error.localizedDescription)")
        }
        DispatchQueue.main.async { NotificationCenter.default.post(name: VpnKeychain.vpnCredentialsChanged, object: vpnCredentials) }
    }
    
    public func clear() {
        appKeychain[data: StorageKey.vpnCredentials] = nil
        do {
            try clearPassword()
            DispatchQueue.main.async { NotificationCenter.default.post(name: VpnKeychain.vpnCredentialsChanged, object: nil) }
        } catch { }
    }
    
    // Password is set and retrieved without using the library because NEVPNProtocol reuquires it to be
    // a "persistent keychain reference to a keychain item containing the password component of the
    // tunneling protocol authentication credential".
    private func getPasswordRefference() throws -> Data {
        var query = formBaseQuery(forKey: StorageKey.vpnServerPassword)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecReturnPersistentRef as AnyHashable] = kCFBooleanTrue
        
        var secItem: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &secItem)
        if result != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
        
        if let item = secItem as? Data {
            return item
        } else {
            throw ProtonVpnErrorConst.vpnCredentialsMissing
        }
    }
    
    private func setPassword(_ password: String) throws {
        do {
            var query = formBaseQuery(forKey: StorageKey.vpnServerPassword)
            query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
            query[kSecReturnAttributes as AnyHashable] = kCFBooleanTrue
            query[kSecReturnData as AnyHashable] = kCFBooleanTrue
            
            var secItem: AnyObject?
            let result = SecItemCopyMatching(query as CFDictionary, &secItem)
            if result != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
            }
            
            guard let data = secItem as? [String: AnyObject],
                let passwordData = data[kSecValueData as String] as? Data,
                let oldPassword = String(data: passwordData, encoding: String.Encoding.utf8) else {
                    throw NSError(domain: NSOSStatusErrorDomain, code: -1, userInfo: nil)
            }
            
            if password != oldPassword {
                throw NSError(domain: NSOSStatusErrorDomain, code: -1, userInfo: nil)
            }
        } catch {
            do {
                try clearPassword()
            } catch { }
            
            var query = formBaseQuery(forKey: StorageKey.vpnServerPassword)
            query[kSecValueData as AnyHashable] = password.data(using: String.Encoding.utf8) as Any
            
            let result = SecItemAdd(query as CFDictionary, nil)
            if result != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
            }
        }
    }
    
    private func clearPassword() throws {
        let query = formBaseQuery(forKey: StorageKey.vpnServerPassword)
        
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }
    
    private func formBaseQuery(forKey key: String) -> [AnyHashable: Any] {
        return [
            kSecClass as AnyHashable: kSecClassGenericPassword,
            kSecAttrGeneric as AnyHashable: key,
            kSecAttrAccount as AnyHashable: key,
            kSecAttrService as AnyHashable: key,
            kSecAttrAccessible as AnyHashable: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as [AnyHashable: Any]
    }
    
    // MARK: -
    // Dealing with old vpn password entry.
    // These can be deleted after all users have iOS version > 1.3.2 and MacOs app version > 1.5.5
    
    public func hasOldVpnPassword() -> Bool {
        var query = formBaseQuery(forKey: StorageKey.openVpnPassword_old)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecReturnPersistentRef as AnyHashable] = kCFBooleanTrue
        query[kSecAttrAccessible as AnyHashable] = kSecAttrAccessibleAlwaysThisDeviceOnly
        
        var secItem: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &secItem)
        if result != errSecSuccess {
            return false
        }

        return secItem != nil && secItem is Data
    }
    
    public func clearOldVpnPassword() throws {
        var query = formBaseQuery(forKey: StorageKey.openVpnPassword_old)
        query[kSecAttrAccessible as AnyHashable] = kSecAttrAccessibleAlwaysThisDeviceOnly
        
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }
    
}
