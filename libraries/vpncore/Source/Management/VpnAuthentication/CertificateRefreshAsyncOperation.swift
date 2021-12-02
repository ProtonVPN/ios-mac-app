//
//  CertificateRefreshAsyncOperation.swift
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

enum CertificateRefreshError: Error {
    case canceled
}

final class CertificateRefreshAsyncOperation: AsyncOperation {
    private let storage: VpnAuthenticationStorage
    private let networking: Networking
    private let completion: CertificateRefreshCompletion?
    private var isRetry = false

    init(storage: VpnAuthenticationStorage, networking: Networking, completion: CertificateRefreshCompletion? = nil) {
        self.storage = storage
        self.networking = networking
        self.completion = completion
    }

    private func finish(_ result: Result<(VpnAuthenticationData), Error>) {
        completion?(result)
        finish()
    }

    private func getCertificate(keys: VpnKeys, completion: @escaping (Result<VpnCertificate, Error>) -> Void) {
        log.debug("Asking backend API for new vpn authentication certificate", category: .userCert, event: .newCertificate)
        let request = CertificateRequest(publicKey: keys.publicKey)
        networking.request(request) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(dict):
                do {
                    let certificate = try VpnCertificate(dict: dict)
                    log.debug("Got new vpn authentication certificate valid until \(certificate.validUntil)", category: .userCert, event: .newCertificate)
                    completion(.success(certificate))
                } catch {
                    log.error("Failed to decode vpn authentication certificate from backend: \(error)", category: .userCert, event: .refreshError)
                    completion(.failure(error))
                }
            case let .failure(error):
                log.error("Failed to get vpn authentication certificate from backend: \(error)", category: .userCert, event: .refreshError)
                completion(.failure(error))
            }
        }
    }

    override func main() {
        guard !isCancelled else {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        log.debug("Checking if vpn authentication certificate refresh is needed", category: .userCert)

        let keys = storage.getKeys()
        let existingCertificate = storage.getStoredCertificate()

        let needsRefresh: Bool
        if let certificate = existingCertificate {
            // check if we are past the refresh time recommended by the backend or expired
            needsRefresh = certificate.isExpired || certificate.shouldBeRefreshed
        } else {
            log.debug("No stored vpn authentication certificate found", category: .userCert)
            // no certificate exists, refresh is definitely needed
            needsRefresh = true
        }

        guard needsRefresh else {
            log.debug("Stored vpn authentication certificate does not need refreshing (valid until \(existingCertificate!.validUntil))", category: .userCert)
            finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate!.certificate)))
            return
        }

        guard !isCancelled else {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        // fetch new certificate from backend
        getCertificate(keys: keys) { result in
            guard !self.isCancelled else {
                self.finish(.failure(CertificateRefreshError.canceled))
                return
            }

            switch result {
            case let .failure(error):
                let nsError = error as NSError
                switch nsError.code {
                case 2500 where !self.isRetry: // error ClientPublicKey fingerprint conflict, please regenerate a new key
                    log.error("Trying to recover by generating new keys and trying again", category: .userCert, event: .refreshError)
                    self.storage.deleteKeys()
                    self.storage.deleteCertificate()
                    self.isRetry = true
                    self.main()
                default:
                    self.finish(.failure(error))
                }
            case let .success(certificate):
                // store it
                self.storage.store(certificate: certificate)
                self.finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
            }
        }
    }
}
