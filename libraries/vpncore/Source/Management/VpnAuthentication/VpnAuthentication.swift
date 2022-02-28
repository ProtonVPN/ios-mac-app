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

public protocol VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication
}

public typealias CertificateRefreshCompletion = (Result<(VpnAuthenticationData), Error>) -> Void
public typealias AuthenticationDataCompletion = (Result<VpnAuthenticationData, Error>) -> Void

public protocol VpnAuthentication {
    /**
     Refreshes the client certificate if needed
     */
    func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion)

    /**
     Loads authentication data consisting of private key and client certificate that is needed to connect with a certificate base protocol

     ***Note** The certificate might be expired. The expired certificate still allows to connect to VPN but the app will get jailed and needs to fetch a new certificate with the `refreshCertificates` method

     Takes care of generating the keys if they are missing and refreshing the client certificate if needed.
     */
    func loadAuthenticationData(features: VPNConnectionFeatures?, completion: @escaping AuthenticationDataCompletion)
    
    /// Deletes current certificate
    func clearCertificate()
    
    /// Deletes all the generated and stored data, so keys and certificate
    func clearEverything()
}

public extension VpnAuthentication {
    
    func refreshCertificates(completion: @escaping CertificateRefreshCompletion) {
        refreshCertificates(features: nil, completion: completion)
    }
    
    func loadAuthenticationData(completion: @escaping AuthenticationDataCompletion) {
        loadAuthenticationData(features: nil, completion: completion)
    }
    
}

public final class VpnAuthenticationManager {
    private let queue = OperationQueue()
    private let storage: VpnAuthenticationStorage
    private let networking: Networking
    private let safeModePropertyProvider: SafeModePropertyProvider

    public init(networking: Networking, storage: VpnAuthenticationStorage, safeModePropertyProvider: SafeModePropertyProvider) {
        self.networking = networking
        self.storage = storage
        self.safeModePropertyProvider = safeModePropertyProvider
        queue.maxConcurrentOperationCount = 1

        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnUserDelinquent, object: nil)
    }

    @objc private func userDowngradedPlanOrBecameDelinquent(_ notification: NSNotification) {
        log.info("User plan downgraded or delinquent, deleting keys and certificate and getting one ones", category: .userCert)

        // certificate refresh requests might be in progress so first cancel all fo them
        queue.cancelAllOperations()
        
        // Save last used features before cleanup
        let features = storage.getStoredCertificateFeatures()

        // then delete evertyhing
        clearEverything()

        // and get new certificates
        queue.addOperation(CertificateRefreshAsyncOperation(storage: storage, features: features, networking: networking, safeModePropertyProvider: safeModePropertyProvider))
    }
}

extension VpnAuthenticationManager: VpnAuthentication {
    public func clearEverything() {
        // First cancel all pending certificate refreshes so a certificate is not fetched from the backend and stored after deleting keychain in this call
        queue.cancelAllOperations()

        // Delete everything from the keychain
        storage.deleteKeys()
        storage.deleteCertificate()
    }
    
    public func clearCertificate() {
        // First cancel all pending certificate refreshes so a certificate is not fetched from the backend and stored after deleting keychain in this call
        queue.cancelAllOperations()
        
        // Felete only certificate
        storage.deleteCertificate()
    }

    public func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        // If new ferature set is given, use it, otherwise try to get certificate with the same features as previous
        let newFeatures = features ?? storage.getStoredCertificateFeatures()

        queue.addOperation(CertificateRefreshAsyncOperation(storage: storage, features: newFeatures, networking: networking, safeModePropertyProvider: safeModePropertyProvider, completion: { result in
            executeOnUIThread { completion(result) }
        }))
    }

    public func loadAuthenticationData(features: VPNConnectionFeatures? = nil, completion: @escaping AuthenticationDataCompletion) {
        // keys are generated, certificate is stored, use it
        if let keys = storage.getStoredKeys(), let existingCertificate = storage.getStoredCertificate(), features == nil || features?.equals(other: storage.getStoredCertificateFeatures(), safeModeEnabled: safeModePropertyProvider.safeModeFeatureEnabled) == true {
            log.debug("Loading stored vpn authentication data", category: .userCert)
            if existingCertificate.isExpired {
                log.info("Stored vpn authentication certificate is expired (\(existingCertificate.validUntil)), the local agent will connect but certificate refresh will be needed", category: .userCert, event: .newCertificate)
            }
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate.certificate)))
            return
        }

        // certificate is missing or no longer valid, refresh it and use
        refreshCertificates(features: features, completion: { result in
            executeOnUIThread { completion(result) }
        })
    }
}
