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

import Dependencies

import Domain
import ExtensionIPC
import VPNShared

#if os(iOS)
public final class VpnAuthenticationRemoteClient: VpnAuthentication {
    private var connectionProvider: ProviderMessageSender?
    private let sessionService: SessionService
    private let authenticationStorage: VpnAuthenticationStorageSync

    public typealias Factory = SessionServiceFactory &
        VpnAuthenticationStorageFactory &
        SafeModePropertyProviderFactory

    public convenience init(_ factory: Factory) {
        self.init(
            sessionService: factory.makeSessionService(),
            authenticationStorage: factory.makeVpnAuthenticationStorage()
        )
    }

    public init(
        sessionService: SessionService,
        authenticationStorage: VpnAuthenticationStorageSync
    ) {
        self.sessionService = sessionService
        self.authenticationStorage = authenticationStorage

        NotificationCenter.default.addObserver(forName: VpnKeychain.vpnPlanChanged, object: nil, queue: nil,
                                               using: userDowngradedPlanOrBecameDelinquent(_:))
        NotificationCenter.default.addObserver(forName: VpnKeychain.vpnUserDelinquent, object: nil, queue: nil,
                                               using: userDowngradedPlanOrBecameDelinquent(_:))
    }

    public func setConnectionProvider(provider: ProviderMessageSender?) {
        connectionProvider = provider
    }

    public func loadAuthenticationData(
        features: VPNConnectionFeatures? = nil,
        completion: @escaping AuthenticationDataCompletion
    ) {
        if let fullAuthData = loadStoredAuthenticationData() {
            if !isValid(authData: fullAuthData) {
                log.warning("Deleting invalid certificate from storage", category: .userCert)
                authenticationStorage.deleteCertificate()
            } else if !needsRefresh(fullAuthData, features: features) {
                let vpnAuthData = VpnAuthenticationData(
                    clientKey: fullAuthData.keys.privateKey,
                    clientCertificate: fullAuthData.certificate.certificate
                )
                log.debug(
                    "Stored VPN auth data does not need refreshing",
                    category: .userCert,
                    metadata: ["vpnAuthData": "\(fullAuthData)"]
                )
                completion(.success(vpnAuthData))
                return
            }
        }

        // certificate is missing or no longer valid, refresh it and use
        self.refreshCertificates(features: features, completion: { result in
            switch result {
            case .success:
                log.info("Refreshed certificate", category: .userCert)
            case .failure(let error):
                log.error("Failed to refresh certificate: \(error)", category: .userCert)
            }
            executeOnUIThread { completion(result) }
        })
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
            log.error("Attempted to refresh certificate with no provider set. Check that the connection is active before refreshing.", category: .userCert)
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
                        completionHandler(.failure(ProtonVpnError.userCredentialsMissing))
                        return
                    }

                    log.info(
                        "Certificate retrieved from extension",
                        category: .userCert,
                        metadata: ["certificate": "\(certificate)"]
                    )
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
                completionHandler(.failure(ProtonVpnError.userCredentialsExpired))
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
    /// main app's responsibility to (re)fork its session and send the selector to the extension.
    private func pushSelectorToProvider(extensionContext: AppContext = .wireGuardExtension, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        Task {
            do {
                let selector = try await sessionService.getExtensionSessionSelector(extensionContext: extensionContext)
                pushToProvider(selector: selector, completionHandler: completionHandler)
            } catch {
                log.error("Received error forking API session: \(error)", category: .userCert)
            }
        }
    }

    private func pushToProvider(selector: String, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        // If we get a success condition, we should look at the session cookie, because the network extension is going
        // to need to send it to the server to avoid getting a 422. Sending a session cookie is required if the two
        // clients aren't sending requests from the same IP, which is possible if the app hasn't connected to the VPN yet.
        // The network extension will always send requests from behind the tunnel (except when it can't, because of the
        // Apple's "killswitch").
        let sessionId = sessionService.sessionCookie
        let request = WireguardProviderRequest.setApiSelector(selector, withSessionCookie: sessionId)

        connectionProvider?.send(request, completion: { result in
            switch result {
            case .success(let response):
                switch response {
                case .ok:
                    completionHandler(.success(()))
                case .error(let message):
                    completionHandler(.failure(ProviderMessageError.remoteError(message: message)))
                case .errorTooManyCertRequests:
                    log.assertionFailure("Received \(response) after trying to renew session?")
                    completionHandler(.failure(AuthenticationRemoteClientError.tooManyCertRequests(retryAfter: nil)))
                case .errorSessionExpired, .errorNeedKeyRegeneration:
                    // We should only ever expect these responses for cert refreshes, not for this entry point.
                    // If we're hitting this, something is very wrong.
                    log.assertionFailure("Received \(response) after trying to renew session?")
                    completionHandler(.failure(ProtonVpnError.userCredentialsExpired))
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        })
    }

    private func syncStorageManipulationWithExtension(closure: @escaping (() -> Void), finished: (() -> Void)? = nil) {
        guard let connectionProvider = connectionProvider else {
            closure()
            return
        }

        connectionProvider.send(WireguardProviderRequest.cancelRefreshes, completion: { [weak self] result in
            // This is not great, but we should still continue with removing the items from the keychain if it fails.
            if case let .failure(error) = result {
                log.error("Could not stop manager remotely: \(error)", category: .userCert)
                log.assertionFailure("Could not stop manager remotely: \(error)")
            }

            closure()

            self?.connectionProvider?.send(WireguardProviderRequest.restartRefreshes, completion: { result in
                if case let .failure(error) = result {
                    log.error("Could not stop manager remotely: \(error)", category: .userCert)
                    log.assertionFailure("Could not stop manager remotely: \(error)")
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

    /// As this calls getKeys(), instead of getStoredKeys(), it can generate a new keypair if one does not exist
    public func loadClientPrivateKey() -> PrivateKey {
        return authenticationStorage.getKeys().privateKey
    }

    /// Allow new certificate to be fetched on feature changes. On iOS, the NE can be launched by the system without
    /// the app being present. Due to this edge case, the saved certificate must specify features, so that they can
    /// be applied on connection without relying on LocalAgent.
    public let shouldIgnoreFeatureChanges: Bool = false

    // MARK: Certificate loading and validation implemenetation details

    /// Contains a bit more information than VpnAuthenticationData.
    /// Used within this class to allow additional verification
    private struct FullAuthData {
        let keys: VpnKeys
        let certificate: VpnCertificate
    }

    private func loadStoredAuthenticationData() -> FullAuthData? {
        log.debug("Loading stored VPN auth data", category: .userCert)

        // Check whether we have an existing certificate saved first, to detect the edge case where we have a
        // certificate but no keys
        guard let certificate = authenticationStorage.getStoredCertificate() else {
            log.debug("No stored VPN certificate found", category: .userCert)
            return nil
        }
        log.debug("Fetched stored VPN auth certificate", category: .userCert, metadata: ["certificate": "\(certificate)"])

        // If we have a leftover certificate, but no keys, they will have to be regenerated, and the certificate will
        // be unusable
        guard let keys = authenticationStorage.getStoredKeys() else {
            log.error("Missing VPN keys, deleting stored certificate", category: .userCert)
            authenticationStorage.deleteCertificate()
            return nil
        }
        log.debug("Fetched stored VPN keys", category: .userCert, metadata: ["keys": "\(keys)"])

        return FullAuthData(keys: keys, certificate: certificate)
    }

    private func isValid(authData: FullAuthData) -> Bool {
        @Dependency(\.featureFlagProvider) var featureFlags
        guard featureFlags[\.mismatchedCertificateRecovery] else {
            log.debug("Skipping certificate validation, Mismatched Certificate Recovery is off", category: .userCert)
            return true
        }

        let publicKey = Data(authData.keys.publicKey.rawRepresentation)
        do {
            let certificatePublicKey = try authData.certificate.getPublicKey()

            // Verify that the certificate was generated against our current keys. This ensures we can recover when an old
            // certificate is left over after plan change/logout. The underlying issue is caused by data races during
            // certificate generation/clearing keys
            // Otherwise, LocalAgent will choke when attempting to connect, and it cannot recover until a new certificate is
            // generated
            guard certificatePublicKey == publicKey else {
                log.error(
                    "Stored certificate as its public key does not match our current keys",
                    category: .userCert,
                    metadata: [
                        "publicKeyFingerprint": "\(publicKey.fingerprint)",
                        "certificatePublicKeyFingerprint": "\(certificatePublicKey.fingerprint)"
                    ]
                )
                return false
            }
        } catch {
            log.error(
                "Could not verify certificate's public key matches our current keys",
                category: .userCert,
                metadata: ["error": "\(error)"]
            )
            // We couldn't verify that the certificate was generated against our current public key, but we might still
            // be able to connect with it if it's just a problem with Sec functions. Return true and give LocalAgent a
            // chance
            return true
        }

        return true
    }

    private func needsRefresh(_ authData: FullAuthData, features: VPNConnectionFeatures?) -> Bool {
        if authData.certificate.isExpired || authData.certificate.shouldBeRefreshed {
            log.info(
                "Stored certificate is either expired or almost expired. Local agent will connect but certificate refresh will be needed",
                category: .userCert,
                event: .newCertificate,
                metadata: ["validUntil": "\(authData.certificate.validUntil)"]
            )
        }

        @Dependency(\.featureFlagProvider) var featureFlagProvider
        let safeModeFeatureEnabled = featureFlagProvider[\.safeMode]

        let storedFeatures = authenticationStorage.getStoredCertificateFeatures()
        if let features, !features.equals(other: storedFeatures, safeModeFeatureEnabled: safeModeFeatureEnabled) {
            log.info(
                "Current features are different from saved certificate's features - certificate needs refresh.",
                category: .userCert,
                metadata: ["currentFeatures": "\(features)", "savedFeatures": "\(String(describing: storedFeatures))"]
            )
            return true
        }

        return false
    }
}
#endif
