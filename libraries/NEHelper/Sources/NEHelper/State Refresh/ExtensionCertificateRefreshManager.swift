//
//  CertificateRefreshManager.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

import Domain
import Timer
import VPNShared

public enum CertificateRefreshError: Error {
    case timedOut
    case cancelled
    case needNewKeys
    case sessionExpiredOrMissing
    case tooManyCertRequests(retryAfter: TimeInterval?)
    case internalError(message: String)
}

public typealias CertificateRefreshCompletion = ((Result<(), CertificateRefreshError>) -> Void)

/// Class for making sure there is always up-to-date certificate.
/// After running `start()` for the first time, will start Timer to run a minute before certificates `RefreshTime`.
public final class ExtensionCertificateRefreshManager: RefreshManager {
    /// All intervals are in seconds unless otherwise mentioned.
    struct Intervals {
        /// How long to wait for another enqueued operation to complete before timing it out.
        var refreshWaitTimeout: DispatchTimeInterval = .seconds(2 * 60)
        /// Check certificate every this number of seconds
        var checkInterval: TimeInterval = 2 * 60
        /// Certificate will be refreshed this number of seconds earlier than requested to lessen the possibility of
        /// refreshing it by both app and extension. It's better for this time to be greater than value of
        /// `checkInterval`, so check happens at least once during this period.
        var refreshEarlierBy: TimeInterval = -3 * 60
    }
    fileprivate static var intervals = Intervals()

    private let vpnAuthenticationStorage: VpnAuthenticationStorageSync
    private let apiService: ExtensionAPIService
    private var timer: BackgroundTimer?

    /// Use an operation queue so we can cancel any pending work items if needed.
    private let operationQueue = OperationQueue()

    /// Ensures only one request is processed at a time. Before sending a request, decrement the semaphore. When
    /// the completion is called and the request is processed, increment the semaphore so the next request can be made.
    fileprivate let semaphore = DispatchSemaphore(value: 0)

    override public var timerRefreshInterval: TimeInterval {
        Self.intervals.checkInterval
    }

    public init(apiService: ExtensionAPIService,
                timerFactory: TimerFactory,
                vpnAuthenticationStorage: VpnAuthenticationStorageSync,
                keychain: AuthKeychainHandle) {
        let workQueue = DispatchQueue(label: "ch.protonvpn.extension.wireguard.certificate-refresh")

        self.vpnAuthenticationStorage = vpnAuthenticationStorage
        self.apiService = apiService

        operationQueue.maxConcurrentOperationCount = 1
        semaphore.signal()

        operationQueue.qualityOfService = .default
        operationQueue.underlyingQueue = workQueue

        super.init(timerFactory: timerFactory,
                   workQueue: workQueue)
    }

    deinit {
        guard state == .stopped else {
            fatalError("Attempted to free refresh manager before stopping it")
        }

        // Make sure we have our turn on the semaphore (should be ok if we're in the stopped state)
        semaphore.wait()
    }

    /// Check the refresh conditions for certificate refresh, and refresh it if necessary.
    ///
    /// This function gets called in several places:
    ///     - At extension startup
    ///     - On firing of the `backgroundTimer`
    ///     - From the app, via the `WireguardProviderMessage.refreshCertificate` remote procedure call
    ///
    /// Because of this, all requests to refresh the certificate are serialized to avoid races. Calls may
    /// take a while to complete (or time out) due to network conditions, or because multiple API calls are
    /// occasionally necessary to refresh the cert (because of session management).
    public func checkRefreshCertificateNow(features: VPNConnectionFeatures?,
                                           userInitiated: Bool = false,
                                           forceRefreshDueToExpiredSession: Bool = false,
                                           completion: @escaping CertificateRefreshCompletion) {
        if operationQueue.isSuspended {
            log.error("Adding certificate refresh operation to suspended refresh manager", category: .userCert)
        }
        operationQueue.addOperation(CertificateRefreshAsyncOperation(features: features,
                                                                     userInitiated: userInitiated,
                                                                     forceRefreshDueToExpiredSession: forceRefreshDueToExpiredSession,
                                                                     manager: self,
                                                                     completion: completion))
    }

    /// Running timers in NE proved to be not very reliable, so we run it every `checkInterval` seconds all the time,
    /// to make sure we don't miss the time when certificate has to be refreshed.
    override internal func work() {
        let features = vpnAuthenticationStorage.getStoredCertificateFeatures()

        checkRefreshCertificateNow(features: features, completion: { result in
            if case let .failure(error) = result {
                log.error("Encountered error \(error) while refreshing in background.", category: .userCert)
                return
            }
            log.info("Background refresh of certificate completed successfully.", category: .userCert)
        })
    }

    /// If the cert refresh manager's session expires, this function needs to be called with a forked session selector
    /// in order to start it back up again with a fresh API session.
    public func newSession(withSelector selector: String, sessionCookie: HTTPCookie?, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        let timeOutInterval = Self.intervals.refreshWaitTimeout
        guard semaphore.wait(timeout: .now() + timeOutInterval) == .success else {
            log.assertionFailure("Timed out waiting for semaphore while starting new session")
            completionHandler(.failure(CertificateRefreshError.timedOut))
            return
        }

        apiService.startSession(withSelector: selector, sessionCookie: sessionCookie) { [weak self] result in
            defer { self?.semaphore.signal() }

            if case let .failure(error) = result {
                log.error("Could not start session due to error: \(error)", category: .userCert)
                completionHandler(result)
                return
            }

            let features = self?.vpnAuthenticationStorage.getStoredCertificateFeatures()
            // If we're starting a new session, we need to get a new certificate to avoid getting a 409 Key Conflict error.
            self?.checkRefreshCertificateNow(features: features, forceRefreshDueToExpiredSession: true, completion: { result in
                completionHandler(result.mapError({ $0 }))
            })
        }
    }

    // MARK: - Private
    private func certificateDoesNeedRefreshing(features: VPNConnectionFeatures?) -> Bool {
        // If we're able to get a certificate from the keychain...
        guard let storedCert = vpnAuthenticationStorage.getStoredCertificate() else {
            log.info("Could not find stored certificate, refreshing.", category: .userCert)
            return true
        }

        if let features = features {
            // and we're also able to retrieve the features stored from the last request...
            guard let storedFeatures = vpnAuthenticationStorage.getStoredCertificateFeatures() else {
                log.info("Could not find stored certificate features, refreshing.", category: .userCert)
                return true
            }

            // and the features we stored from the last request are the same as the ones for this request...
            guard storedFeatures.equals(other: features, safeModeFeatureEnabled: true) else {
                log.info("Features have been updated (or haven't been stored), refreshing.", category: .userCert)
                return true
            }
        }

        // and the certificate isn't going to expire anytime soon, then...
        guard Date() < storedCert.refreshTime.addingTimeInterval(Self.intervals.refreshEarlierBy) else {
            log.info(
                "Certificate might expire soon or has already expired, refreshing.",
                category: .userCert,
                metadata: ["certificateExpiry": "\(storedCert.validUntil)"]
            )
            return true
        }

        // don't actually refresh the certificate, just leave it be.
        let interval = storedCert.refreshTime.timeIntervalSinceNow
        log.info("Certificate seems up to date! Will need to refresh in \(interval.asColonSeparatedString)", category: .userCert)
        return false
    }

    /// Check the refresh conditions for certificate refresh, and refresh if necessary, with no
    /// synchronization performed.
    ///
    /// - Note: *Do not* call this function. Call `checkRefreshCertificateNow` instead. Because of the nature
    ///         of the synchronization in the encapsulating function, it's important to always call the completion
    ///         in error cases, otherwise the operation queue will get stuck.
    fileprivate func checkRefreshCertificateNowNoSync(features: VPNConnectionFeatures?,
                                                      userInitiated: Bool,
                                                      forceRefreshDueToExpiredSession: Bool,
                                                      asPartOf operation: CertificateRefreshAsyncOperation,
                                                      completion: @escaping CertificateRefreshCompletion) {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        guard forceRefreshDueToExpiredSession || certificateDoesNeedRefreshing(features: features) else {
            completion(.success(()))
            return
        }

        guard let keys = vpnAuthenticationStorage.getStoredKeys() else {
            completion(.failure(.needNewKeys))
            return
        }

        let der = keys.publicKey.derRepresentation
        apiService.refreshCertificate(publicKey: der, asPartOf: operation) { [weak self] result in
            switch result {
            case .success(let cert):
                let certAndFeatures = VpnCertificateWithFeatures(certificate: cert, features: features)
                self?.vpnAuthenticationStorage.store(certAndFeatures)
                completion(.success(()))
            case .failure(let error):
                guard let certError = error as? CertificateRefreshError else {
                    completion(.failure(.internalError(message: String(describing: error))))
                    return
                }

                switch certError {
                // If the session has expired or our keys need regenerating, then we need to wait for the app to give
                // us a new session or regenerate our keys before we can start again. The app should receive these errors
                // to know it needs to send us something.
                case .sessionExpiredOrMissing, .needNewKeys:
                    break
                // If the API tells us we need to calm down, display this error to the user.
                case .tooManyCertRequests:
                    break
                // This should happen rarely in times of network congestion or connectivity issues, and should
                // be handled directly by the caller, who should swallow & log the error to avoid confusing the app.
                case .cancelled:
                    break
                // This shouldn't happen from here; the caller should be managing the semaphore.
                case .timedOut:
                    log.assertionFailure("Should not encounter \(certError) here; we aren't managing synchronization", category: .userCert)
                // These errors should "never happen" in practice.
                case .internalError:
                    log.assertionFailure("Encountered internal error: \(error)", category: .userCert)
                }

                completion(.failure(certError))
            }
        }
    }

    override public func stop(completion: @escaping (() -> Void)) {
        super.stop { [weak self] in
            self?.operationQueue.addBarrierBlock {
                self?.operationQueue.isSuspended = true
                completion()
            }
        }
    }

    override public func start(completion: @escaping (() -> Void)) {
        super.start { [weak self] in
            self?.operationQueue.isSuspended = false
            completion()
        }
    }

    override func stopTimer() {
        operationQueue.cancelAllOperations()
        super.stopTimer()
    }
}

class CertificateRefreshAsyncOperation: AsyncOperation {
    let features: VPNConnectionFeatures?
    let isUserInitiated: Bool
    let forceRefreshDueToExpiredSession: Bool
    let completion: CertificateRefreshCompletion

    var observation: NSKeyValueObservation!
    unowned let manager: ExtensionCertificateRefreshManager

    init(features: VPNConnectionFeatures?,
         userInitiated: Bool,
         forceRefreshDueToExpiredSession: Bool,
         manager: ExtensionCertificateRefreshManager,
         completion: @escaping CertificateRefreshCompletion) {
        self.features = features
        self.isUserInitiated = userInitiated
        self.forceRefreshDueToExpiredSession = forceRefreshDueToExpiredSession
        self.manager = manager
        self.completion = completion
    }

    private func finish(_ result: Result<(), CertificateRefreshError>) {
        completion(result)
        finish()
    }

    override func main() {
        let timeOutInterval = ExtensionCertificateRefreshManager.intervals.refreshWaitTimeout
        guard manager.semaphore.wait(timeout: .now() + timeOutInterval) == .success else {
            log.assertionFailure("Timed out waiting for semaphore while performing certificate refresh")
            finish(.failure(.timedOut))
            return
        }

        guard !isCancelled else {
            finish(.failure(.cancelled))
            manager.semaphore.signal()
            return
        }

        var didFire = false
        observation = observe(\.isCancelled, options: [.initial]) { [weak self] _, _ in
            guard self?.isCancelled == true else { return }
            self?.finish(.failure(.cancelled))
            self?.manager.semaphore.signal()
            didFire = true
        }

        guard !isCancelled else { return }
        manager.checkRefreshCertificateNowNoSync(features: features,
                                                 userInitiated: isUserInitiated,
                                                 forceRefreshDueToExpiredSession: forceRefreshDueToExpiredSession,
                                                 asPartOf: self) { result in
            guard !self.isCancelled else { return }
            self.observation.invalidate()

            guard !self.isCancelled else {
                // if on the off chance we were cancelled between when we checked and when we invalidated the
                // observation, make sure we still manage to signal the semaphore.
                if !didFire {
                    self.finish(.failure(.cancelled))
                    self.manager.semaphore.signal()
                }
                return
            }

            self.finish(result)
            self.manager.semaphore.signal()
        }
    }
}
