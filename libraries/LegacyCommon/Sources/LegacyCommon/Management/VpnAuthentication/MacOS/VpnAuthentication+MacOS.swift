//
//  Created on 12/05/2023.
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

import Domain
import Ergonomics
import VPNShared

#if os(macOS)
/// MacOS implementation of Certificate Refresh management
public final class VpnAuthenticationManager: VpnAuthentication {
    private let operationDispatchQueue = DispatchQueue(label: "ch.protonvpn.mac.async_cert_refresh",
                                                       qos: .userInitiated)
    private let queue = OperationQueue()
    private let storage: VpnAuthenticationStorageSync
    private let networking: Networking

    public typealias Factory = NetworkingFactory &
        VpnAuthenticationStorageFactory

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking(), storage: factory.makeVpnAuthenticationStorage())
    }

    public init(networking: Networking, storage: VpnAuthenticationStorageSync) {
        self.networking = networking
        self.storage = storage
        queue.maxConcurrentOperationCount = 1
        queue.underlyingQueue = operationDispatchQueue

        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDowngradedPlanOrBecameDelinquent), name: VpnKeychain.vpnUserDelinquent, object: nil)
    }

    @objc private func userDowngradedPlanOrBecameDelinquent(_ notification: NSNotification) {
        log.info("User plan downgraded or delinquent, deleting keys and certificate and getting new ones", category: .userCert)

        // certificate refresh requests might be in progress so first cancel all fo them
        queue.cancelAllOperations()

        // then delete evertyhing
        clearEverything { [weak self] in
            guard let self = self else {
                return
            }

            // and get new certificates
            self.queue.addOperation(CertificateRefreshAsyncOperation(storage: self.storage, networking: self.networking))
        }
    }

    public func loadAuthenticationData(features: VPNConnectionFeatures? = nil, completion: @escaping AuthenticationDataCompletion) {
        // keys are generated, certificate is stored, use it
        if let keys = storage.getStoredKeys(), let existingCertificate = storage.getStoredCertificate() {
            log.debug("Loading stored vpn authentication data", category: .userCert)
            if existingCertificate.isExpired {
                log.info("Stored vpn authentication certificate is expired (\(existingCertificate.validUntil)), the local agent will connect but certificate refresh will be needed", category: .userCert, event: .newCertificate)
            }
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey,
                                                      clientCertificate: existingCertificate.certificate)))
            return
        }

        // certificate is missing or no longer valid, refresh it and use
        self.refreshCertificates(features: features, completion: completion)
    }

    public func clearEverything(completion: @escaping (() -> Void)) {
        // First cancel all pending certificate refreshes so a certificate is not fetched from the backend and stored after deleting keychain in this call
        queue.cancelAllOperations()

        // Delete everything from the keychain
        storage.deleteKeys()
        storage.deleteCertificate()

        completion()
    }

    /// - Parameter features: The features used for the current connection. Ignored on MacOS
    /// - Parameter completion: A function which will be invoked on the UI thread with the refreshed
    ///                         certificate, or an error if the refresh failed.
    public func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        queue.addOperation(CertificateRefreshAsyncOperation(storage: storage, networking: networking, completion: { result in
            executeOnUIThread { completion(result) }
        }))
    }

    public func loadClientPrivateKey() -> PrivateKey {
        return storage.getKeys().privateKey
    }

    public var shouldIgnoreFeatureChanges: Bool {
        true // Ignore feature changes. LA is guaranteed to be present on MacOS,
    }
}
#endif
