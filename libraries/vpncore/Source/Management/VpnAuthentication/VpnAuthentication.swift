//
//  vpnAuthentication.swift
//  vpncore - Created on 06.04.2021.
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

public struct VpnAuthenticationData {
    public let clientKey: String
    public let clientCertificate: String
}

public protocol VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication
}

public protocol VpnAuthentication {
    /**
     Refreshes the client certificate
     */
    func refreshCertificates(completion: @escaping (Result<(VpnAuthenticationData), Error>) -> Void)

    /**
     Loads authentication data consisting of private key and client certificate that is needed to connect with a certificate base protocol

     Takes care of generating the keys if they are missing and refreshing the client certificate if needed.
     */
    func loadAuthenticationData(completion: @escaping (Result<VpnAuthenticationData, Error>) -> Void)

    /**
     Invalidates the certificate, if one is stored. Should be called on user plan upgrade, downgrade, delinquent
     */
    func invalidateCertificate()

    /**
     Deletes all the generated and stored data, so keys and certificate
     */
    func clear()
}

public final class VpnAuthenticationManager {
    struct VpnKeys: Codable {
        let privateKey: String
        let publicKey: String
    }

    struct VpnCertificate: Codable {
        let certificate: String
        let validUntil: Date

        init(certificate: String, validUntil: Date) {
            self.certificate = certificate
            self.validUntil = validUntil
        }

        init(dict: JSONDictionary) throws {
            certificate = try dict.stringOrThrow(key: "Certificate")
            validUntil = try dict.unixTimestampOrThrow(key: "ExpirationTime")
        }
    }

    private struct StorageKey {
        static let vpnKeys = "vpnKeys"
        static let vpnCertificate = "vpnCertificate"
    }

    private let appKeychain = Keychain(service: CoreAppConstants.appKeychain).accessibility(.afterFirstUnlockThisDeviceOnly)
    private let alamofireWrapper: AlamofireWrapper
    private let certificateRefreshDeadline: TimeInterval = 60 * 60 * 3 // 3 hours

    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }

    private func generateKeys() -> VpnKeys {
        return VpnKeys(
            privateKey: """
            -----BEGIN PRIVATE KEY-----
            MC4CAQAwBQYDK2VwBCIEIAxWc8RF4Rn42sPDqPqTY9uOhcsI7Xnm7aSi7n8k1HGz
            -----END PRIVATE KEY-----
            """,
            publicKey: """
            -----BEGIN PUBLIC KEY-----
            MCowBQYDK2VwAyEALorY7BXtHmfCW7NgeKGV5DL7EFmrpdjd+BbFEPlZE6U=
            -----END PUBLIC KEY-----
            """
        )
    }

    private func getStoredCertificate() -> VpnCertificate? {
       do {
            guard let json = try appKeychain.getData(StorageKey.vpnCertificate) else {
                return nil
            }

            let certificate = try JSONDecoder().decode(VpnCertificate.self, from: json)
            return certificate
        } catch {
            PMLog.D("Keychain (vpn) read error: \(error)", level: .error)
            return nil
        }
    }

    private func getStoredKeys() -> VpnKeys? {
        do {
            guard let json = try appKeychain.getData(StorageKey.vpnKeys) else {
                return nil
            }

            let keys = try JSONDecoder().decode(VpnKeys.self, from: json)
            return keys
        } catch {
            PMLog.D("Keychain (vpn) read error: \(error)", level: .error)
            return nil
        }
    }

    private func store(keys: VpnKeys) {
        do {
            let data = try JSONEncoder().encode(keys)
            try appKeychain.set(data, key: StorageKey.vpnKeys)
        } catch {
            PMLog.D("Saving generated vpn auth keyes failed \(error)", level: .error)
        }
    }

    private func store(certificate: VpnCertificate) {
        do {
            let data = try JSONEncoder().encode(certificate)
            try appKeychain.set(data, key: StorageKey.vpnCertificate)
        } catch {
            PMLog.D("Saving generated vpn auth keyes failed \(error)", level: .error)
        }
    }

    private func deleteKeys() {
        appKeychain[StorageKey.vpnKeys] = nil
    }

    private func deleteCertificate() {
        appKeychain[StorageKey.vpnCertificate] = nil
    }

    // swiftlint:disable function_body_length
    private func getCertificate(keys: VpnKeys, completion: @escaping (Result<VpnCertificate, Error>) -> Void) {
        /*PMLog.D("Asking backend API for new vpn auth certificate")
        let request = CertificateRequest(publicKey: keys.publicKey)
        self.alamofireWrapper.request(request) { (dict: JSONDictionary) in
            do {
                let certificate = try VpnCertificate(dict: dict)
                DispatchQueue.main.async {
                    completion(.success(certificate))
                }
            } catch {
                PMLog.ET("Failed to decoded vpn auth certificate from backend: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        } failure: { error in
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }*/
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            PMLog.D("Got vpn auth certificate from backend API")
            let certificate = VpnCertificate(certificate:
                """
                Certificate:
                    Data:
                        Version: 3 (0x2)
                        Serial Number:
                            d1:27:fd:e0:31:9c:31:f9:b9:4d:2a:16:d6:e4:04:7b
                        Signature Algorithm: ED25519
                        Issuer: CN=Proton AG
                        Validity
                            Not Before: Mar 21 06:07:18 2021 GMT
                            Not After : Jun 24 06:07:18 2023 GMT
                        Subject: C=CH, L=Geneva, O=Proton, OU=VPN, CN=test-cert5/emailAddress=test-cert5@protonmail.ch
                        Subject Public Key Info:
                            Public Key Algorithm: ED25519
                                ED25519 Public-Key:
                                pub:
                                    2e:8a:d8:ec:15:ed:1e:67:c2:5b:b3:60:78:a1:95:
                                    e4:32:fb:10:59:ab:a5:d8:dd:f8:16:c5:10:f9:59:
                                    13:a5
                        X509v3 extensions:
                            X509v3 Basic Constraints:
                                CA:FALSE
                            X509v3 Subject Key Identifier:
                                B0:59:9D:76:A1:C8:42:0B:65:31:B4:9E:83:18:82:EF:73:9E:B6:21
                            X509v3 Authority Key Identifier:
                                keyid:38:A2:00:7F:F8:A2:52:0F:48:0F:9D:16:7B:09:71:67:0E:8F:C1:7B
                                DirName:/CN=Proton AG
                                serial:14:E1:7E:40:4D:E6:C5:E5:27:EA:E7:43:FC:78:6E:3C:54:A0:7C:2A

                            X509v3 Extended Key Usage:
                                TLS Web Client Authentication
                            X509v3 Key Usage:
                                Digital Signature
                    Signature Algorithm: ED25519
                         c3:ac:9c:5e:06:70:a3:bd:6a:a7:53:d6:3c:a1:00:e4:99:a3:
                         72:c3:fd:7d:d5:58:dd:9a:aa:91:8d:29:9f:4a:7b:76:d8:f6:
                         88:da:7f:ef:44:9a:83:49:ab:eb:0d:26:b2:af:a9:55:9b:5d:
                         e1:92:dc:fc:30:19:49:df:3c:04
                -----BEGIN CERTIFICATE-----
                MIIB7zCCAaGgAwIBAgIRANEn/eAxnDH5uU0qFtbkBHswBQYDK2VwMBQxEjAQBgNV
                BAMMCVByb3RvbiBBRzAeFw0yMTAzMjEwNjA3MThaFw0yMzA2MjQwNjA3MThaMHsx
                CzAJBgNVBAYTAkNIMQ8wDQYDVQQHDAZHZW5ldmExDzANBgNVBAoMBlByb3RvbjEM
                MAoGA1UECwwDVlBOMRMwEQYDVQQDDAp0ZXN0LWNlcnQ1MScwJQYJKoZIhvcNAQkB
                Fhh0ZXN0LWNlcnQ1QHByb3Rvbm1haWwuY2gwKjAFBgMrZXADIQAuitjsFe0eZ8Jb
                s2B4oZXkMvsQWaul2N34FsUQ+VkTpaOBoDCBnTAJBgNVHRMEAjAAMB0GA1UdDgQW
                BBSwWZ12ochCC2UxtJ6DGILvc562ITBPBgNVHSMESDBGgBQ4ogB/+KJSD0gPnRZ7
                CXFnDo/Be6EYpBYwFDESMBAGA1UEAwwJUHJvdG9uIEFHghQU4X5ATebF5Sfq50P8
                eG48VKB8KjATBgNVHSUEDDAKBggrBgEFBQcDAjALBgNVHQ8EBAMCB4AwBQYDK2Vw
                A0EAw6ycXgZwo71qp1PWPKEA5JmjcsP9fdVY3ZqqkY0pn0p7dtj2iNp/70Sag0mr
                6w0msq+pVZtd4ZLc/DAZSd88BA==
                -----END CERTIFICATE-----

                """, validUntil: Date().addingTimeInterval(60 * 60 * 4)) // 4 hours, change for testing
            completion(.success(certificate))
        }
    }

    private func getKeys() -> VpnKeys {
        // get or generate the keys first
        let keys: VpnKeys
        if let existingKeys = self.getStoredKeys() {
            keys = existingKeys
        } else {
            PMLog.D("No vpn auth keys, generating and storing")
            keys = self.generateKeys()
            self.store(keys: keys)
        }

        return keys
    }
}

extension VpnAuthenticationManager: VpnAuthentication {
    public func clear() {
        deleteKeys()
        deleteCertificate()
    }

    public func invalidateCertificate() {
        deleteCertificate()
    }

    public func refreshCertificates(completion: @escaping (Result<(VpnAuthenticationData), Error>) -> Void) {
        // simple synchornization to make sure this method is not call multiple times in parallel
        objc_sync_enter(self)

        let keys = getKeys()
        let existingCertificate = self.getStoredCertificate()

        let needsRefresh: Bool
        if let certificate = existingCertificate {
            // refresh is needed if the certificate expired before a safe interval
            needsRefresh = certificate.validUntil < Date().addingTimeInterval(certificateRefreshDeadline)
        } else {
            // no certificate exists, refresh is definitelly needed
            needsRefresh = true
        }

        guard needsRefresh else {
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate!.certificate)))
            objc_sync_exit(self)
            return
        }

        // fetch new certificate from backend
        self.getCertificate(keys: keys) { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(certificate):
                // store it
                self.store(certificate: certificate)
                completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
            }
            objc_sync_exit(self)
        }
        return
    }

    public func loadAuthenticationData(completion: @escaping (Result<VpnAuthenticationData, Error>) -> Void) {
        // keys are generated, certificate is stored and still valid, use it
        if let keys = getStoredKeys(), let existingCertificate = getStoredCertificate(), existingCertificate.validUntil < Date() {
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate.certificate)))
            return
        }

        // certificate is missing or no longer valid, refresh it and use
        refreshCertificates(completion: completion)
    }
}
