//
//  VpnAuthenticationStorage.swift
//  vpncore - Created on 16.04.2021.
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

import Dependencies
import Domain
import Ergonomics
import Foundation
import KeychainAccess
import PMLogger

public enum VpnAuthenticationStorageEvent: Sendable, Equatable {
    case certificateDeleted
    case certificateStored(VpnCertificate)
}

public struct VpnAuthenticationStorage: Sendable {
    public var deleteKeys: @Sendable () -> Void
    public var deleteCertificate: @Sendable () -> Void
    public var getKeys: @Sendable () -> VpnKeys
    public var getStoredCertificate: @Sendable () -> VpnCertificate?
    public var getStoredKeys: @Sendable () -> VpnKeys?
    public var storeKeys: @Sendable (VpnKeys) -> Void
    public var storeCertificate: @Sendable (VpnCertificate) -> Void
    public var storeCertificateWithFeatures: @Sendable (VpnCertificateWithFeatures) -> Void
    public var getStoredCertificateFeatures: @Sendable () -> VPNConnectionFeatures?
    public var events: AsyncStream<VpnAuthenticationStorageEvent>

    public init(
        deleteKeys: @escaping @Sendable () -> Void,
        deleteCertificate: @escaping @Sendable () -> Void,
        getKeys: @escaping @Sendable () -> VpnKeys,
        getStoredCertificate: @escaping @Sendable () -> VpnCertificate?,
        getStoredKeys: @escaping @Sendable () -> VpnKeys?,
        storeKeys: @escaping @Sendable (VpnKeys) -> Void,
        storeCertificate: @escaping @Sendable (VpnCertificate) -> Void,
        storeCertificateWithFeatures: @escaping @Sendable (VpnCertificateWithFeatures) -> Void,
        getStoredCertificateFeatures: @escaping @Sendable () -> VPNConnectionFeatures?,
        events: AsyncStream<VpnAuthenticationStorageEvent>
    ) {
        self.deleteKeys = deleteKeys
        self.deleteCertificate = deleteCertificate
        self.getKeys = getKeys
        self.getStoredCertificate = getStoredCertificate
        self.getStoredKeys = getStoredKeys
        self.storeKeys = storeKeys
        self.storeCertificate = storeCertificate
        self.storeCertificateWithFeatures = storeCertificateWithFeatures
        self.getStoredCertificateFeatures = getStoredCertificateFeatures
        self.events = events
    }

    // Convenience methods for backwards compatibility
    public func store(keys: VpnKeys) {
        storeKeys(keys)
    }

    public func store(_ certificate: VpnCertificate) {
        storeCertificate(certificate)
    }

    public func store(_ certificate: VpnCertificateWithFeatures) {
        storeCertificateWithFeatures(certificate)
    }
}

public enum VPNAuthenticationStorageConfigKey: DependencyKey {
    public static var liveValue: String = {
        #if os(iOS) || os(tvOS)
            "\(DomainConstants.appIdentifierPrefix)prt.ProtonVPN"
        #elseif os(macOS)
            "\(DomainConstants.appIdentifierPrefix)ch.protonvpn.macos"
        #else
            "\(DomainConstants.appIdentifierPrefix)prt.ProtonVPN"
        #endif
    }()

    public static let testValue: String = "test.prt.ProtonVPN"
}

extension VpnAuthenticationStorage: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.vpnAuthenticationStorageConfig) var accessGroup
        @Dependency(\.vpnKeysGenerator) var vpnKeysGenerator
        @Dependency(\.storage) var storage

        let appKeychain = KeychainActor(accessGroup: accessGroup)
        let (stream, continuation) = AsyncStream.makeStream(of: VpnAuthenticationStorageEvent.self)

        let deleteCertificateImpl: @Sendable () -> Void = {
            log.info("Deleting existing vpn authentication certificate", category: .userCert)
            appKeychain.clear(contextValues: ["vpnCertificate"])
            continuation.yield(.certificateDeleted)
        }

        let deleteKeysImpl: @Sendable () -> Void = {
            log.info("Deleting existing vpn authentication keys", category: .userCert)
            appKeychain.clear(contextValues: ["vpnKeys"])
            deleteCertificateImpl()
        }

        let getStoredKeysImpl: @Sendable () -> VpnKeys? = {
            do {
                guard let json = try appKeychain.getData("vpnKeys") else {
                    return nil
                }
                return try JSONDecoder().decode(VpnKeys.self, from: json)
            } catch {
                log.error("Keychain (vpn) read error: \(error)", category: .userCert)
                // If keys are broken then the certificate is also unusable, so just delete everything and start again
                deleteKeysImpl()
                return nil
            }
        }

        let storeKeysImpl: @Sendable (VpnKeys) -> Void = { keys in
            do {
                let data = try JSONEncoder().encode(keys)
                try appKeychain.set(data, key: "vpnKeys")
            } catch {
                log.error("Saving generated vpn auth keys failed \(error)", category: .userCert)
            }
        }

        let getKeysImpl: @Sendable () -> VpnKeys = {
            let keys: VpnKeys
            if let existingKeys = getStoredKeysImpl() {
                log.info("Using existing vpn authentication keys", category: .userCert)
                keys = existingKeys
            } else {
                log.info("No vpn auth keys, generating and storing", category: .userCert)
                keys = try! vpnKeysGenerator.generateKeys()
                log.info("Storing new VPN keys", category: .userCert, metadata: ["keys": "\(keys)"])
                storeKeysImpl(keys)
            }
            return keys
        }

        let getStoredCertificateImpl: @Sendable () -> VpnCertificate? = {
            do {
                guard let json = try appKeychain.getData("vpnCertificate") else {
                    return nil
                }
                return try JSONDecoder().decode(VpnCertificate.self, from: json)
            } catch {
                log.error("Keychain (vpn) read error: \(error)", category: .userCert)
                return nil
            }
        }

        let storeCertificateDataImpl: @Sendable (VpnCertificate) throws -> Void = { certificate in
            let data = try JSONEncoder().encode(certificate)
            try appKeychain.set(data, key: "vpnCertificate")
        }

        let storeCertificateImpl: @Sendable (VpnCertificate) -> Void = { certificate in
            do {
                try storeCertificateDataImpl(certificate)
                log.debug("VPN certificate saved, valid until: \(certificate.validUntil)", category: .userCert)
                continuation.yield(.certificateStored(certificate))
            } catch {
                log.error("Saving VPN certificate failed with error: \(error)", category: .userCert)
            }
        }

        let storeCertificateWithFeaturesImpl: @Sendable (VpnCertificateWithFeatures) -> Void = { certificateWithFeatures in
            do {
                try storeCertificateDataImpl(certificateWithFeatures.certificate)
                try storage.set(certificateWithFeatures.features, forKey: "vpnCertificateFeatures")
                log.debug(
                    "Certificate with features saved",
                    category: .userCert,
                    metadata: [
                        "certificate": "\(certificateWithFeatures)",
                        "features": "\(String(describing: certificateWithFeatures.features))",
                    ]
                )
                continuation.yield(.certificateStored(certificateWithFeatures.certificate))
            } catch {
                log.error("Saving VPN certificate failed with error: \(error)", category: .userCert)
            }
        }

        let getStoredCertificateFeaturesImpl: @Sendable () -> VPNConnectionFeatures? = {
            try? storage.get(VPNConnectionFeatures.self, forKey: "vpnCertificateFeatures")
        }

        return Self(
            deleteKeys: deleteKeysImpl,
            deleteCertificate: deleteCertificateImpl,
            getKeys: getKeysImpl,
            getStoredCertificate: getStoredCertificateImpl,
            getStoredKeys: getStoredKeysImpl,
            storeKeys: storeKeysImpl,
            storeCertificate: storeCertificateImpl,
            storeCertificateWithFeatures: storeCertificateWithFeaturesImpl,
            getStoredCertificateFeatures: getStoredCertificateFeaturesImpl,
            events: stream
        )
    }()

    #if DEBUG
        public static let testValue: Self = {
            let (stream, continuation) = AsyncStream.makeStream(of: VpnAuthenticationStorageEvent.self)

            return Self(
                deleteKeys: { continuation.yield(.certificateDeleted) },
                deleteCertificate: { continuation.yield(.certificateDeleted) },
                getKeys: { VpnKeys.mock() },
                getStoredCertificate: { nil },
                getStoredKeys: { nil },
                storeKeys: { _ in },
                storeCertificate: { certificate in continuation.yield(.certificateStored(certificate)) },
                storeCertificateWithFeatures: { certificateWithFeatures in
                    continuation.yield(.certificateStored(certificateWithFeatures.certificate))
                },
                getStoredCertificateFeatures: { nil },
                events: stream
            )
        }()

        /// Creates a test storage with mutable state for use in tests
        public static func testStorage(
            keys: VpnKeys? = nil,
            certificate: VpnCertificate? = nil,
            features: VPNConnectionFeatures? = nil
        ) -> Self {
            final class StorageState: @unchecked Sendable {
                var keys: VpnKeys?
                var cert: VpnCertificate?
                var features: VPNConnectionFeatures?

                init(keys: VpnKeys?, cert: VpnCertificate?, features: VPNConnectionFeatures?) {
                    self.keys = keys
                    self.cert = cert
                    self.features = features
                }
            }

            let state = StorageState(keys: keys, cert: certificate, features: features)
            let (stream, continuation) = AsyncStream.makeStream(of: VpnAuthenticationStorageEvent.self)

            return Self(
                deleteKeys: {
                    state.keys = nil
                    state.cert = nil
                    continuation.yield(.certificateDeleted)
                },
                deleteCertificate: {
                    state.cert = nil
                    continuation.yield(.certificateDeleted)
                },
                getKeys: {
                    if let keys = state.keys {
                        return keys
                    }
                    let newKeys = VpnKeys.mock()
                    state.keys = newKeys
                    return newKeys
                },
                getStoredCertificate: { state.cert },
                getStoredKeys: { state.keys },
                storeKeys: { state.keys = $0 },
                storeCertificate: {
                    state.cert = $0
                    continuation.yield(.certificateStored($0))
                },
                storeCertificateWithFeatures: {
                    state.cert = $0.certificate
                    state.features = $0.features
                    continuation.yield(.certificateStored($0.certificate))
                },
                getStoredCertificateFeatures: { state.features },
                events: stream
            )
        }
    #endif
}

public extension DependencyValues {
    var vpnAuthenticationStorage: VpnAuthenticationStorage {
        get { self[VpnAuthenticationStorage.self] }
        set { self[VpnAuthenticationStorage.self] = newValue }
    }

    var vpnAuthenticationStorageConfig: String {
        get { self[VPNAuthenticationStorageConfigKey.self] }
        set { self[VPNAuthenticationStorageConfigKey.self] = newValue }
    }
}
