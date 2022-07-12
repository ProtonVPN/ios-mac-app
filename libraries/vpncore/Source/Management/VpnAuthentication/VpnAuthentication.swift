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

public typealias CertificateRefreshCompletion = (Result<VpnAuthenticationData, Error>) -> Void
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

    /// Loads the client private key needed for establishing a connection. Generates keypair if the keys are missing.
    func loadClientPrivateKey() -> PrivateKey

    /// Deletes all the generated and stored data, so keys and certificate
    func clearEverything(completion: @escaping (() -> Void))
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

    public init(networking: Networking,
                storage: VpnAuthenticationStorage,
                safeModePropertyProvider: SafeModePropertyProvider) {
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
        clearEverything { [weak self] in
            guard let `self` = self else { return }

            // and get new certificates
            self.queue.addOperation(CertificateRefreshAsyncOperation(storage: self.storage,
                                                                     features: features,
                                                                     networking: self.networking,
                                                                     safeModePropertyProvider: self.safeModePropertyProvider))
        }
    }

    /// Created for the purposes of sharing refresh logic between VpnAuthenticationManager and VpnAuthenticationRemoteClient. When VpnAuthenticationManager
    /// is fully replaced by VpnAuthenticationRemoteClient on macOS, this function will be absorbed into VpnAuthenticationRemoteClient.
    fileprivate static func loadAuthenticationDataBase(storage: VpnAuthenticationStorage,
                                                       safeModePropertyProvider: SafeModePropertyProvider,
                                                       features: VPNConnectionFeatures? = nil,
                                                       completion: @escaping AuthenticationDataCompletion) {
        // keys are generated, certificate is stored, use it
        if let keys = storage.getStoredKeys(), let existingCertificate = storage.getStoredCertificate(), features == nil || features?.equals(other: storage.getStoredCertificateFeatures(), safeModeEnabled: safeModePropertyProvider.safeModeFeatureEnabled) == true {
            log.debug("Loading stored vpn authentication data", category: .userCert)
            if existingCertificate.isExpired {
                log.info("Stored vpn authentication certificate is expired (\(existingCertificate.validUntil)), the local agent will connect but certificate refresh will be needed", category: .userCert, event: .newCertificate)
            }
            completion(.success(VpnAuthenticationData(clientKey: keys.privateKey,
                                                      clientCertificate: existingCertificate.certificate)))
            return
        }

        completion(.failure(ProtonVpnErrorConst.vpnCredentialsMissing))
    }
}

extension VpnAuthenticationManager: VpnAuthentication {
    public func clearEverything(completion: @escaping (() -> Void)) {
        // First cancel all pending certificate refreshes so a certificate is not fetched from the backend and stored after deleting keychain in this call
        queue.cancelAllOperations()

        // Delete everything from the keychain
        storage.deleteKeys()
        storage.deleteCertificate()

        completion()
    }

    public func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        // If new ferature set is given, use it, otherwise try to get certificate with the same features as previous
        let newFeatures = features ?? storage.getStoredCertificateFeatures()

        queue.addOperation(CertificateRefreshAsyncOperation(storage: storage, features: newFeatures, networking: networking, safeModePropertyProvider: safeModePropertyProvider, completion: { result in
            executeOnUIThread { completion(result) }
        }))
    }

    public func loadAuthenticationData(features: VPNConnectionFeatures? = nil, completion: @escaping AuthenticationDataCompletion) {
        Self.loadAuthenticationDataBase(storage: storage, safeModePropertyProvider: safeModePropertyProvider, features: features) { result in
            guard case let .failure(error) = result, (error as NSError) == ProtonVpnErrorConst.vpnCredentialsMissing else {
                completion(result)
                return
            }

            // certificate is missing or no longer valid, refresh it and use
            self.refreshCertificates(features: features, completion: { result in
                executeOnUIThread { completion(result) }
            })
        }
    }

    public func loadClientPrivateKey() -> PrivateKey {
        return storage.getKeys().privateKey
    }
}

public enum AuthenticationRemoteClientError: Error {
    case needNewKeys
    case tooManyCertRequests(retryAfter: TimeInterval?)
}

public final class VpnAuthenticationRemoteClient {
    private var connectionProvider: ProviderMessageSender?
    private let sessionService: SessionService
    private let authenticationStorage: VpnAuthenticationStorage
    private let safeModePropertyProvider: SafeModePropertyProvider

    public init(sessionService: SessionService,
                authenticationStorage: VpnAuthenticationStorage,
                safeModePropertyProvider: SafeModePropertyProvider) {
        self.sessionService = sessionService
        self.authenticationStorage = authenticationStorage
        self.safeModePropertyProvider = safeModePropertyProvider

        NotificationCenter.default.addObserver(forName: VpnKeychain.vpnPlanChanged, object: nil, queue: nil,
                                               using: userDowngradedPlanOrBecameDelinquent(_:))
        NotificationCenter.default.addObserver(forName: VpnKeychain.vpnUserDelinquent, object: nil, queue: nil,
                                               using: userDowngradedPlanOrBecameDelinquent(_:))
    }

    public func setConnectionProvider(provider: ProviderMessageSender?) {
        connectionProvider = provider
    }

    /// Ask the WireGuard network extension to refresh the certificate, and save the result to the keychain.
    ///
    /// If the network extension does not have a valid API session, it will return a message asking the app to "fork" the
    /// app's API session, and send the selector representing this forked session to the network extension. The extension
    /// will then authenticate with the API, establish its session, and tell the app that it's ready to try again,
    /// at which point the app is welcome to do so. When the network extension returns success after being asked to refresh
    /// the certificate, the updated certificate should be available in the keychain.
    private func promptExtensionForCertificateRefresh(features: VPNConnectionFeatures?,
                                                      retryingForExpiredSessions: Bool = true,
                                                      completionHandler: @escaping CertificateRefreshCompletion) {
        guard let connectionProvider = connectionProvider else {
            log.error("Attempted to refresh certificate with no provider set. Check that the connection is active before refreshing.")
            completionHandler(.failure(ProviderMessageError.sendingError))
            return
        }

        connectionProvider.send(WireguardProviderRequest.refreshCertificate(features: features)) { [weak self] result in
            switch result {
            case .success(let response):
                switch response {
                case .ok:
                    // Extension has updated the certificate and placed it in the keychain. Let's fetch it on our end.
                    guard let keys = self?.authenticationStorage.getStoredKeys(),
                          let certificate = self?.authenticationStorage.getStoredCertificate() else {
                        completionHandler(.failure(ProtonVpnErrorConst.userCredentialsMissing))
                        return
                    }
                    
                    log.info("Certificate retrieved from extension. Expires on \(certificate.validUntil), should refresh before \(certificate.refreshTime)")
                    completionHandler(.success(VpnAuthenticationData(clientKey: keys.privateKey,
                                                                     clientCertificate: certificate.certificate)))
                    return
                case .error(let message):
                    completionHandler(.failure(ProviderMessageError.remoteError(message: message)))
                case .errorSessionExpired:
                    self?.handleSessionExpired(features: features,
                                               retryingForExpiredSessions: retryingForExpiredSessions,
                                               completionHandler: completionHandler)
                case .errorNeedKeyRegeneration:
                    self?.authenticationStorage.deleteKeys()
                    self?.authenticationStorage.deleteCertificate()
                    completionHandler(.failure(AuthenticationRemoteClientError.needNewKeys))
                case .errorTooManyCertRequests(let retryAfter):
                    if let retryAfter = retryAfter {
                        completionHandler(.failure(AuthenticationRemoteClientError.tooManyCertRequests(retryAfter: TimeInterval(retryAfter))))
                    } else {
                        completionHandler(.failure(AuthenticationRemoteClientError.tooManyCertRequests(retryAfter: nil)))
                    }
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    /// Handle the session expiring in the network extension by forking a new API session, pushing that session selector
    /// to the provider, and then prompting the extension to once again renew its certificate.
    private func handleSessionExpired(features: VPNConnectionFeatures?,
                                      retryingForExpiredSessions: Bool,
                                      completionHandler: @escaping CertificateRefreshCompletion) {
        pushSelectorToProvider { [weak self] pushResult in
            if case let .failure(error) = pushResult {
                completionHandler(.failure(error))
                return
            }
            guard retryingForExpiredSessions else {
                completionHandler(.failure(ProtonVpnErrorConst.userCredentialsExpired))
                return
            }
            self?.promptExtensionForCertificateRefresh(features: features,
                                                       retryingForExpiredSessions: false,
                                                       completionHandler: completionHandler)
        }
    }

    /// Fork a child API session in the network extension that will manage this connection.
    ///
    /// The network extension maintains its own API session. When we ask it to refresh certificates for us, it
    /// may find that its session has expired, or that it does not have any session saved in its keychain. In such
    /// a case, it will reply to refresh requests with `.errorSessionExpired`, at which point it will be the
    /// main app's responsability to (re)fork its session and send the selector to the extension.
    private func pushSelectorToProvider(extensionContext: AppContext = .wireGuardExtension, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        sessionService.getExtensionSessionSelector(extensionContext: extensionContext) { [weak self] apiResult in
            guard case let .success(selector) = apiResult else {
                if case let .failure(error) = apiResult {
                    log.error("Received error forking API session: \(error)")
                }
                return
            }

            // If we get a success condition, we should look at the session cookie, because the network extension is going
            // to need to send it to the server to avoid getting a 422. Sending a session cookie is required if the two
            // clients aren't sending requests from the same IP, which is possible if the app hasn't connected to the VPN yet.
            // The network extension will always send requests from behind the tunnel.
            let sessionId = self?.sessionService.sessionCookie
            let request = WireguardProviderRequest.setApiSelector(selector, withSessionCookie: sessionId)

            self?.connectionProvider?.send(request, completion: { result in
                switch result {
                case .success(let response):
                    switch response {
                    case .ok:
                        completionHandler(.success(()))
                    case .error(let message):
                        completionHandler(.failure(ProviderMessageError.remoteError(message: message)))
                    case .errorTooManyCertRequests:
                        assertionFailure("Received \(response) after trying to renew session?")
                        completionHandler(.failure(AuthenticationRemoteClientError.tooManyCertRequests(retryAfter: nil)))
                    case .errorSessionExpired, .errorNeedKeyRegeneration:
                        // We should only ever expect these responses for cert refreshes, not for this entry point.
                        // If we're hitting this, something is very wrong.
                        assertionFailure("Received \(response) after trying to renew session?")
                        completionHandler(.failure(ProtonVpnErrorConst.userCredentialsExpired))
                    }
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            })
        }
    }

    private func syncStorageManipulationWithExtension(closure: @escaping (() -> Void), finished: (() -> Void)? = nil) {
        guard let connectionProvider = connectionProvider else {
            closure()
            return
        }

        connectionProvider.send(WireguardProviderRequest.cancelRefreshes, completion: { [weak self] result in
            // This is not great, but we should still continue with removing the items from the keychain if it fails.
            if case let .failure(error) = result {
                log.error("Could not stop manager remotely: \(error)")
                assertionFailure("Could not stop manager remotely: \(error)")
            }

            closure()

            self?.connectionProvider?.send(WireguardProviderRequest.restartRefreshes, completion: { result in
                if case let .failure(error) = result {
                    log.error("Could not stop manager remotely: \(error)")
                    assertionFailure("Could not stop manager remotely: \(error)")
                    return
                }
                finished?()
            })
        })
    }

    private func userDowngradedPlanOrBecameDelinquent(_ notification: Notification) {
        log.info("User plan downgraded or delinquent, deleting keys and certificate and getting new ones", category: .userCert)

        var features: VPNConnectionFeatures?
        syncStorageManipulationWithExtension { [weak self] in
            features = self?.authenticationStorage.getStoredCertificateFeatures() // save the old features before clearing them
            self?.authenticationStorage.deleteKeys()
            self?.authenticationStorage.deleteCertificate()

        } finished: { [weak self] in
            _ = self?.authenticationStorage.getKeys() // generate new keys
            self?.refreshCertificates(features: features) { _ in }
        }
    }
}

extension VpnAuthenticationRemoteClient: VpnAuthentication {
    public func loadAuthenticationData(features: VPNConnectionFeatures?, completion: @escaping AuthenticationDataCompletion) {
        VpnAuthenticationManager.loadAuthenticationDataBase(storage: authenticationStorage,
                                                            safeModePropertyProvider: safeModePropertyProvider,
                                                            features: features) { result in
            guard case let .failure(error) = result, (error as NSError) == ProtonVpnErrorConst.vpnCredentialsMissing else {
                completion(result)
                return
            }

            // certificate is missing or no longer valid, refresh it and use
            self.refreshCertificates(features: features, completion: { result in
                executeOnUIThread { completion(result) }
            })
        }
    }

    public func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        promptExtensionForCertificateRefresh(features: features, completionHandler: completion)
    }

    public func clearEverything(completion: @escaping (() -> Void)) {
        syncStorageManipulationWithExtension { [weak self] in
            self?.authenticationStorage.deleteKeys()
            self?.authenticationStorage.deleteCertificate()
            completion()
        }
    }

    public func loadClientPrivateKey() -> PrivateKey {
        return authenticationStorage.getKeys().privateKey
    }
}
