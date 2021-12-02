//
//  VpnAuthenticationKeychain.swift
//  vpncore - Created on 16.04.2021.
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

import Foundation
import KeychainAccess

public protocol VpnAuthenticationStorage {
    func deleteKeys()
    func deleteCertificate()
    func getKeys() -> VpnKeys
    func getStoredCertificate() -> VpnCertificate?
    func getStoredKeys() -> VpnKeys?
    func store(keys: VpnKeys)
    func store(certificate: VpnCertificate)
}

public final class VpnAuthenticationKeychain: VpnAuthenticationStorage {
    private struct StorageKey {
        static let vpnKeys = "vpnKeys"
        static let vpnCertificate = "vpnCertificate"
    }

    private let appKeychain: KeychainAccess.Keychain

    public init(accessGroup: String) {
        appKeychain = KeychainAccess.Keychain(service: KeychainConstants.appKeychain, accessGroup: accessGroup).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    public func deleteKeys() {
        appKeychain[StorageKey.vpnKeys] = nil
        deleteCertificate()
    }

    public func deleteCertificate() {
        appKeychain[StorageKey.vpnCertificate] = nil
    }

    public func getKeys() -> VpnKeys {
        let keys: VpnKeys
        if let existingKeys = self.getStoredKeys() {
            log.info("Using existing vpn authentication keys", category: .userCert)
            keys = existingKeys
        } else {
            log.info("No vpn auth keys, generating and storing", category: .userCert)
            keys = VpnKeys()
            self.store(keys: keys)
        }

        return keys
    }

    public func getStoredCertificate() -> VpnCertificate? {
       do {
            guard let json = try appKeychain.getData(StorageKey.vpnCertificate) else {
                return nil
            }

            let certificate = try JSONDecoder().decode(VpnCertificate.self, from: json)
            return certificate
        } catch {
            log.error("Keychain (vpn) read error: \(error)", category: .userCert)
            return nil
        }
    }

    public func getStoredKeys() -> VpnKeys? {
        do {
            guard let json = try appKeychain.getData(StorageKey.vpnKeys) else {
                return nil
            }

            let keys = try JSONDecoder().decode(VpnKeys.self, from: json)
            return keys
        } catch {
            log.error("Keychain (vpn) read error: \(error)", category: .userCert)
            // If keys are broken then the certificate is also unusable, so just delete everything and start again
            deleteKeys()
            deleteCertificate()
            return nil
        }
    }

    public func store(keys: VpnKeys) {
        do {
            let data = try JSONEncoder().encode(keys)
            try appKeychain.set(data, key: StorageKey.vpnKeys)
        } catch {
            log.error("Saving generated vpn auth keyes failed \(error)", category: .userCert)
        }
    }

    public func store(certificate: VpnCertificate) {
        do {
            let data = try JSONEncoder().encode(certificate)
            try appKeychain.set(data, key: StorageKey.vpnCertificate)
        } catch {
            log.error("Saving generated vpn auth keyes failed \(error)", category: .userCert)
        }
    }
}
