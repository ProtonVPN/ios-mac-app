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
    public let clientKey: PrivateKey
    public let clientCertificate: String
}

public protocol VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication
}

public typealias CertificateRefreshResult = (Result<(VpnAuthenticationData), Error>) -> Void
public typealias AuthenticationDataResult = (Result<VpnAuthenticationData, Error>) -> Void

public protocol VpnAuthentication {
    /**
     Refreshes the client certificate if needed
     */
    func refreshCertificates(completion: @escaping CertificateRefreshResult)

    /**
     Loads authentication data consisting of private key and client certificate that is needed to connect with a certificate base protocol

     Takes care of generating the keys if they are missing and refreshing the client certificate if needed.
     */
    func loadAuthenticationData(completion: @escaping AuthenticationDataResult)

    /**
     Deletes all the generated and stored data, so keys and certificate
     */
    func clear()
}

public final class VpnAuthenticationManager {    
    private struct StorageKey {
        static let vpnKeys = "vpnKeys"
        static let vpnCertificate = "vpnCertificate"
    }

    private var queue: [CertificateRefreshResult] = []
    private var isExecuting = false

    private let appKeychain = Keychain(service: CoreAppConstants.appKeychain).accessibility(.afterFirstUnlockThisDeviceOnly)
    private let alamofireWrapper: AlamofireWrapper
    private let certificateRefreshDeadline: TimeInterval = 60 * 60 * 3 // 3 hours
    private let voidQueueItem: CertificateRefreshResult = { _ in }

    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper

        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnPlanDowngraded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnUserDelinquent, object: nil)
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
            // If keys are broken then the certificate is also unsable, so just delete everything and start again
            clear()
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
        deleteCertificate()
    }

    private func deleteCertificate() {
        appKeychain[StorageKey.vpnCertificate] = nil
    }

    private func getCertificate(keys: VpnKeys, completion: @escaping (Result<VpnCertificate, Error>) -> Void) {
        PMLog.D("Asking backend API for new vpn authentication certificate")
        let request = CertificateRequest(publicKey: keys.publicKey)
        self.alamofireWrapper.request(request) { (dict: JSONDictionary) in
            do {
                let certificate = try VpnCertificate(dict: dict)
                PMLog.D("Got new vpn authentication certificate valid until \(certificate.validUntil)")
                DispatchQueue.main.async {
                    completion(.success(certificate))
                }
            } catch {
                PMLog.ET("Failed to decode vpn authentication certificate from backend: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        } failure: { error in
            PMLog.ET("Failed to get vpn authentication certificate from backend: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    private func getKeys() -> VpnKeys {
        let keys: VpnKeys
        if let existingKeys = self.getStoredKeys() {
            PMLog.D("Using existing vpn authentication keys")
            keys = existingKeys
        } else {
            PMLog.D("No vpn auth keys, generating and storing")
            keys = VpnKeys()
            self.store(keys: keys)
        }

        return keys
    }

    // Simple queue implementation for certificate refresh
    private func execute() {
        // make sure another certificate refresh is not already in progress
        guard !isExecuting else {
            return
        }

        // if the operation queue is empty then stop the queue
        guard let completion = queue.first else {
            isExecuting = false
            return
        }

        // remove the operation to be processed so the queue actually shrinks and does not run forever
        queue.removeFirst()
        PMLog.D("Checking if vpn authentication certificate refresh is needed")

        let keys = getKeys()
        let existingCertificate = self.getStoredCertificate()

        let needsRefresh: Bool
        if let certificate = existingCertificate {
            // refresh is needed if the certificate expired before a safe interval
            needsRefresh = certificate.validUntil < Date().addingTimeInterval(certificateRefreshDeadline)
        } else {
            PMLog.D("No stored vpn authentication certificate found")
            // no certificate exists, refresh is definitelly needed
            needsRefresh = true
        }

        guard needsRefresh else {
            PMLog.D("Stored vpn authentication certificate does not need refreshing (valid until \(existingCertificate!.validUntil)")
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate!.certificate)))
            execute()
            return
        }

        // fetch new certificate from backend
        self.getCertificate(keys: keys) { result in
            switch result {
            case let .failure(error):
                let nsError = error as NSError
                switch nsError.code {
                case 2500: // error ClientPublicKey fingerprint conflict, please regenerate a new key
                    PMLog.D("Trying to recover by generating new keys and trying again")
                    self.clear()
                    self.queue.append(completion)
                    self.execute()
                default:
                    completion(.failure(error))
                    self.execute()
                }
            case let .success(certificate):
                // store it
                self.store(certificate: certificate)
                completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
                self.execute()
            }
        }
    }

    @objc private func userDowngradedPlanOrBecameDelinquent(_ notification: NSNotification ) {
        PMLog.D("User plan downgraded or delinquent, deleting keys and certificate and getting one ones")
        clear()
        queue.append(voidQueueItem)
        execute()
    }
}

extension VpnAuthenticationManager: VpnAuthentication {
    /**
     Deletes all the generated and stored data, so keys and certificate
     */
    public func clear() {
        queue.removeAll()
        deleteKeys()
        deleteCertificate()
    }

    /**
     Refreshes the client certificate if needed

     Uses a queue internally to make sure parallel calls to this method are executed in a serial way. This is important to make sure multiple keys are not generated at the same time.
     */
    public func refreshCertificates(completion: @escaping CertificateRefreshResult) {
        queue.append(completion)
        execute()
    }

    /**
     Loads authentication data consisting of private key and client certificate that is needed to connect with a certificate base protocol

     Takes care of generating the keys if they are missing and refreshing the client certificate if needed.
     */
    public func loadAuthenticationData(completion: @escaping AuthenticationDataResult) {
        // keys are generated, certificate is stored and still valid, use it
        if let keys = getStoredKeys(), let existingCertificate = getStoredCertificate(), existingCertificate.validUntil < Date() {
            PMLog.D("Loading stored vpn authentication data")
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate.certificate)))
            return
        }

        // certificate is missing or no longer valid, refresh it and use
        refreshCertificates(completion: completion)
    }
}
