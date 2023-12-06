//
//  Created on 04/12/2023.
//
//  Copyright (c) 2023 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Dependencies
import KeychainAccess
import Ergonomics
import PMLogger

public final class VpnAuthenticationKeychain: VpnAuthenticationStorageAsync {

    private struct KeychainStorageKey {
        static let vpnKeys = "vpnKeys"
        static let vpnCertificate = "vpnCertificate"
    }

    private struct DefaultsStorageKey {
        static let vpnCertificateFeatures = "vpnCertificateFeatures"
    }

    private let appKeychain: KeychainActor
    private let vpnKeysGenerator: VPNKeysGenerator
    public weak var delegate: VpnAuthenticationStorageDelegate?

    public init(accessGroup: String, vpnKeysGenerator: VPNKeysGenerator) {
        appKeychain = KeychainActor(accessGroup: accessGroup)
        self.vpnKeysGenerator = vpnKeysGenerator
    }

    public func deleteKeys() async {
        log.info("Deleting existing vpn authentication keys", category: .userCert)
        await appKeychain.clear(contextValues: [KeychainStorageKey.vpnKeys])
        await deleteCertificate()
    }

    public func deleteCertificate() async {
        log.info("Deleting existing vpn authentication certificate", category: .userCert)
        await appKeychain.clear(contextValues: [KeychainStorageKey.vpnCertificate])
        delegate?.certificateDeleted()
    }

    public func getKeys() async -> VpnKeys {
        let keys: VpnKeys
        if let existingKeys = await self.getStoredKeys() {
            log.info("Using existing vpn authentication keys", category: .userCert)
            keys = existingKeys
        } else {
            log.info("No vpn auth keys, generating and storing", category: .userCert)
            keys = vpnKeysGenerator.generateKeys()
            log.info("Storing new VPN keys", category: .userCert, metadata: ["keys": "\(keys)"])
            await self.store(keys: keys)
        }

        return keys
    }

    public func getStoredCertificate() async -> VpnCertificate? {
       do {
            guard let json = try await appKeychain.getData(KeychainStorageKey.vpnCertificate) else {
                return nil
            }
            return try JSONDecoder().decode(VpnCertificate.self, from: json)
        } catch {
            log.error("Keychain (vpn) read error: \(error)", category: .userCert)
            return nil
        }
    }

    public func getStoredCertificateFeatures() -> VPNConnectionFeatures? {
        @Dependency(\.storage) var storage
        return try? storage.get(VPNConnectionFeatures.self, forKey: DefaultsStorageKey.vpnCertificateFeatures)
    }

    public func getStoredKeys() async -> VpnKeys? {
        do {
            guard let json = try await appKeychain.getData(KeychainStorageKey.vpnKeys) else {
                return nil
            }

            return try JSONDecoder().decode(VpnKeys.self, from: json)
        } catch {
            log.error("Keychain (vpn) read error: \(error)", category: .userCert)
            // If keys are broken then the certificate is also unusable, so just delete everything and start again
            await deleteKeys()
            await deleteCertificate()
            return nil
        }
    }

    public func store(keys: VpnKeys) async {
        do {
            let data = try JSONEncoder().encode(keys)
            try await appKeychain.set(data, key: KeychainStorageKey.vpnKeys)
        } catch {
            log.error("Saving generated vpn auth keys failed \(error)", category: .userCert)
        }
    }

    public func store(_ certificate: VpnCertificateWithFeatures) async {
        @Dependency(\.storage) var storage
        do {
            try await store(certificate: certificate.certificate)
            try storage.set(certificate.features, forKey: DefaultsStorageKey.vpnCertificateFeatures)
            log.debug(
                "Certificate with features saved",
                category: .userCert,
                metadata: [
                    "certificate": "\(certificate)",
                    "features": "\(String(describing: certificate.features))"
                ]
            )
            await delegate?.certificateStored(certificate.certificate)
        } catch {
            log.error("Saving VPN certificate failed with error: \(error)", category: .userCert)
        }
    }

    public func store(_ certificate: VpnCertificate) async {
        do {
            try await store(certificate: certificate)
            log.debug("VPN certificate saved, valid until: \(certificate.validUntil)", category: .userCert)
            await delegate?.certificateStored(certificate)
        } catch {
            log.error("Saving VPN certificate failed with error: \(error)", category: .userCert)
        }
    }

    private func store(certificate: VpnCertificate) async throws {
        let data = try JSONEncoder().encode(certificate)
        try await appKeychain.set(data, key: KeychainStorageKey.vpnCertificate)
    }
}

