//
//  CertificateRefreshManager.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

public enum CertificateRefreshError: Error {
    case timedOut
    case cancelled
    case missingKeys
    case sessionExpiredOrMissing
    case internalError(message: String)
}

typealias CertificateRefreshCompletion = ((Result<(), CertificateRefreshError>) -> Void)

/// Class for making sure there is always up-to-date certificate.
/// After running `start()` for the first time, will start Timer to run a minute before certificates `RefreshTime`.
final class ExtensionCertificateRefreshManager {
    fileprivate static let refreshWaitTimeoutInSeconds: Int = 2 * 60

    /// Check certificate every this number of seconds
    private let checkInterval: TimeInterval = 2 * 60

    /// Certificate will be refreshed this number of seconds earlier than requested to lessen the possibility of refreshing it by both app and extension.
    /// Its better for this time to be greater than value of `checkInterval`, so check happens at least once during this period.
    private let refreshEarlierBy: TimeInterval = -3 * 60

    private let vpnAuthenticationStorage: VpnAuthenticationStorage
    private let apiService: ExtensionAPIService
    private let timerFactory: TimerFactory
    private var timer: RepeatingTimerProtocol?

    /// Use an operation queue so we can cancel any pending work items if needed.
    private let operationQueue = OperationQueue()
    /// The underlying queue for the operation queue.
    private let workQueue = DispatchQueue(label: "ch.protonvpn.extension.wireguard.certificate-refresh")

    /// Ensures only one request is processed at a time. Before sending a request, decrement the semaphore. When
    /// the completion is called and the request is processed, increment the semaphore so the next request can be made.
    fileprivate let semaphore = DispatchSemaphore(value: 1)

    enum State {
        case running
        case stopped
    }

    public private(set) var state: State = .stopped

    init(apiService: ExtensionAPIService,
         timerFactory: TimerFactory,
         vpnAuthenticationStorage: VpnAuthenticationStorage,
         keychain: AuthKeychainHandle) {
        self.vpnAuthenticationStorage = vpnAuthenticationStorage
        self.timerFactory = timerFactory
        self.apiService = apiService

        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .default
        operationQueue.underlyingQueue = workQueue
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
    public func checkRefreshCertificateNow(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        operationQueue.addOperation(CertificateRefreshAsyncOperation(features: features,
                                                                     manager: self,
                                                                     completion: completion))
    }

    /// If the cert refresh manager's session expires, this function needs to be called with a forked session selector
    /// in order to start it back up again with a fresh API session.
    public func newSession(withSelector selector: String, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        let timeOutInterval = ExtensionCertificateRefreshManager.refreshWaitTimeoutInSeconds
        guard semaphore.wait(wallTimeout: .now() + .seconds(timeOutInterval)) == .success else {
            assertionFailure("Timed out waiting for semaphore while starting new session")
            completionHandler(.failure(CertificateRefreshError.timedOut))
            return
        }

        apiService.startSession(withSelector: selector) { [weak self] result in
            defer { self?.semaphore.signal() }

            // If we're starting a new session, it's likely we've been idle for a while (or were just trying an operation
            // and got back a 422). Opportunistically try to refresh the cert before returning.
            
            guard let features = self?.vpnAuthenticationStorage.getStoredCertificateFeatures() else {
                return
            }

            self?.checkRefreshCertificateNow(features: features, completion: { result in
                completionHandler(result.mapError({ $0 }))
            })
        }
    }

    public func start(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            self?.state = .running
            self?.startTimer()
            completion()
        }
    }

    public func stop(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            self?.operationQueue.cancelAllOperations()
            self?.stopTimer()
            self?.state = .stopped
            completion()
        }
    }

    // MARK: - Private
    private func certificateDoesNeedRefreshing(features: VPNConnectionFeatures?) -> Bool {
        // If we're able to get a certificate from the keychain...
        guard let storedCert = vpnAuthenticationStorage.getStoredCertificate() else {
            log.info("Could not find stored certificate, refreshing.")
            return true
        }

        if let features = features {
            // and we're also able to retrieve the features stored from the last request...
            guard let storedFeatures = vpnAuthenticationStorage.getStoredCertificateFeatures() else {
                log.info("Could not find stored certificate features, refreshing.")
                return true
            }

            // and the features we stored from the last request are the same as the ones for this request...
            guard storedFeatures.equals(other: features, safeModeEnabled: true) else {
                log.info("Features have been updated (or haven't been stored), refreshing.")
                return true
            }
        }

        // and the certificate isn't going to expire anytime soon, then...
        guard Date() < storedCert.refreshTime.addingTimeInterval(refreshEarlierBy) else {
            log.info("Certificate might expire soon or has already expired, refreshing.")
            return true
        }

        // don't actually refresh the certificate, just leave it be.
        log.info("Certificate seems up to date!")
        return false
    }


    /// Check the refresh conditions for certificate refresh, and refresh if necessary, with no
    /// synchronization performed.
    ///
    /// - Note: *Do not* call this function. Call `checkRefreshCertificateNow` instead. Because of the nature
    ///         of the synchronization in the encapsulating function, it's important to always call the completion
    ///         in error cases, otherwise the operation queue will get stuck.
    fileprivate func checkRefreshCertificateNowNoSync(features: VPNConnectionFeatures?,
                                                      asPartOf operation: CertificateRefreshAsyncOperation,
                                                      completion: @escaping CertificateRefreshCompletion) {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        guard certificateDoesNeedRefreshing(features: features) else {
            completion(.success(()))
            return
        }

        guard let keys = vpnAuthenticationStorage.getStoredKeys() else {
            completion(.failure(.missingKeys))
            return
        }

        let der = keys.publicKey.derRepresentation
        apiService.refreshCertificate(publicKey: der, features: features, asPartOf: operation) { [weak self] result in
            switch result {
            case .success(let cert):
                let certAndFeatures = VpnCertificateWithFeatures(certificate: cert, features: features)
                self?.vpnAuthenticationStorage.store(certificate: certAndFeatures)
                completion(.success(()))
            case .failure(let error):
                guard let certError = error as? CertificateRefreshError else {
                    completion(.failure(.internalError(message: String(describing: error))))
                    return
                }

                switch certError {
                // If the session has expired, then we need to wait for the app to give us a new session
                // before we can start again. The app should receive this error to know it needs to send us something.
                case .sessionExpiredOrMissing:
                    break
                // This should happen rarely in times of network congestion or connectivity issues, and should
                // be handled directly by the caller, who should swallow & log the error to avoid confusing the app.
                case .cancelled:
                    break
                // This shouldn't happen from here; the caller should be managing the semaphore.
                case .timedOut:
                    assertionFailure("Should not encounter \(certError) here; we aren't managing synchronization")
                    log.error("Should not encounter \(certError) here; we aren't managing synchronization")
                    break
                // These errors should "never happen" in practice.
                case .missingKeys, .internalError:
                    assertionFailure("Encountered internal error: \(error)")
                    log.error("Encountered internal error: \(error)")
                    break
                }

                completion(.failure(certError))
            }
        }
    }

    // MARK: - Timer

    /// Running timers in NE proved to be not very reliable, so we run it every `checkInterval` seconds all the time,
    /// to make sure we don't miss the time when certificate has to be refreshed.
    /// - Note: Call this function on `workQueue`.
    private func startTimer() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        timer = timerFactory.repeatingTimer(runAt: Date(), repeating: checkInterval, queue: workQueue) { [weak self] in
            let features = self?.vpnAuthenticationStorage.getStoredCertificateFeatures()
            
            self?.checkRefreshCertificateNow(features: features, completion: { result in
                if case let .failure(error) = result {
                    log.error("Encountered error \(error) while refreshing in background.")
                    return
                }
                log.info("Background refresh of certificate completed successfully.")
            })
        }
    }

    /// Stop the timer by deinit'ing it.
    /// - Note: Call this function on `workQueue`.
    private func stopTimer() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        self.timer = nil
    }
}

class CertificateRefreshAsyncOperation: AsyncOperation {
    let features: VPNConnectionFeatures?
    let completion: CertificateRefreshCompletion
    unowned let manager: ExtensionCertificateRefreshManager

    init(features: VPNConnectionFeatures?,
         manager: ExtensionCertificateRefreshManager,
         completion: @escaping CertificateRefreshCompletion) {
        self.features = features
        self.manager = manager
        self.completion = completion
    }

    private func finish(_ result: Result<(), CertificateRefreshError>) {
        completion(result)
        finish()
    }

    override func main() {
        guard !isCancelled else {
            finish(.failure(.cancelled))
            return
        }

        let timeOutInterval = ExtensionCertificateRefreshManager.refreshWaitTimeoutInSeconds
        guard manager.semaphore.wait(wallTimeout: .now() + .seconds(timeOutInterval)) == .success else {
            assertionFailure("Timed out waiting for semaphore while performing certificate refresh")
            finish(.failure(.timedOut))
            return
        }

        // we could have been blocked for a little while, let's double-check we aren't cancelled
        guard !isCancelled else {
            manager.semaphore.signal()
            finish(.failure(.cancelled))
            return
        }

        manager.checkRefreshCertificateNowNoSync(features: features, asPartOf: self) { result in
            self.finish(result)
            self.manager.semaphore.signal()
        }
    }
}
