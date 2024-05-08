//
//  CertificateRefreshAsyncOperation.swift
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

import Foundation
import CommonNetworking
import VPNShared
import Logging

// MacOS Certificate Refresh operation
final class CertificateRefreshAsyncOperation: AsyncOperation {
    private let storage: VpnAuthenticationStorageSync
    private let networking: Networking
    private let completion: CertificateRefreshCompletion?

    private var isConflictRetry = false
    private var remainingNetworkErrorRetries = 5
    private var shouldRetryDueToNetworkIssue: Bool {
        remainingNetworkErrorRetries > 0
    }

    private let minNetworkErrorRetryDelay: UInt32 = 10
    private let networkErrorRetryDelayJitter: UInt32 = 5
    private var networkRetryDelay: UInt32 {
        let jitter = UInt32.random(in: 0...networkErrorRetryDelayJitter)
        return minNetworkErrorRetryDelay + jitter
    }

    init(storage: VpnAuthenticationStorageSync, networking: Networking, completion: CertificateRefreshCompletion? = nil) {
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
        // Features should not be specified when requesting certificates on MacOS, as LA is always available to manage features
        let request = CertificateRequest(publicKey: keys.publicKey, features: nil)
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

    func handleError(_ error: Error) {
        guard !(error.shouldRetry && shouldRetryDueToNetworkIssue) else {
            self.remainingNetworkErrorRetries -= 1
            let delay = networkRetryDelay
            log.info("Cert refresh failed due to network error \(error). Retrying in \(delay) seconds.", category: .userCert)
            sleep(delay)
            self.main()
            return
        }

        let nsError = error as NSError
        switch nsError.code {
        case 2500 where !self.isConflictRetry: // error ClientPublicKey fingerprint conflict, please regenerate a new key
            log.error("Trying to recover by generating new keys and trying again",
                      category: .userCert, event: .refreshError)
            self.storage.deleteKeys()
            self.storage.deleteCertificate()
            self.isConflictRetry = true
            self.main()
        default:
            self.finish(.failure(error))
        }
    }

    override func main() {
        guard !isCancelled else {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        log.debug("Checking if vpn authentication certificate refresh is needed", category: .userCert)

        let keys = storage.getKeys()

        if let certificate = storage.getStoredCertificate(), !isRefreshNeeded(for: certificate) {
            let metadata: Logger.Metadata = ["validUntil": "\(certificate.validUntil)", "refreshTime": "\(certificate.refreshTime)"]
            log.debug("Stored vpn authentication certificate does not need refreshing", category: .userCert, metadata: metadata)
            finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
            return
        }

        if isCancelled {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        // fetch new certificate from backend
        getCertificate(keys: keys) { [unowned self] result in
            if self.isCancelled {
                self.finish(.failure(CertificateRefreshError.canceled))
                return
            }

            switch result {
            case let .failure(error):
                self.handleError(error)
            case let .success(certificate):
                self.storage.store(certificate)
                self.finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
            }
        }
    }

    private func isRefreshNeeded(for certificate: VpnCertificate) -> Bool {
        if certificate.isExpired || certificate.shouldBeRefreshed {
            let metadata: Logger.Metadata = ["validUntil": "\(certificate.validUntil)", "refreshTime": "\(certificate.refreshTime)"]
            log.info("Certificate has expired or should be refreshed", category: .userCert, metadata: metadata)
            return true
        }
        return false
    }
}
