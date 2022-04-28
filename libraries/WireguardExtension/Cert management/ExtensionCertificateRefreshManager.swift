//
//  CertificateRefreshManager.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

/// Class for making sure there is always up-to-date certificate.
/// After running `start()` for the first time, will start Timer to run a minute before certificates `RefreshTime`.
final class ExtensionCertificateRefreshManager {

    /// Check certificate every this number of seconds
    private var checkInterval: TimeInterval = 2 * 60

    /// Certificate will be refreshed this number of seconds earlier than requested to lessen the possibility of refreshing it by both app and extension.
    /// Its better for this time to be greater than value of `checkInterval`, so check happens at least once during this period.
    private var refreshEarlierBy: TimeInterval = -3 * 60

    private let vpnAuthenticationStorage: VpnAuthenticationStorage
    private let apiService: ExtensionAPIService

    init(storage: Storage, connectionFactory: ConnectionSessionFactory, vpnAuthenticationStorage: VpnAuthenticationStorage, keychain: AuthKeychainHandle) {
        self.vpnAuthenticationStorage = vpnAuthenticationStorage
        self.apiService = ExtensionAPIService(storage: storage, connectionFactory: connectionFactory, keychain: keychain)
    }
    
    func start() {
        startTimer(at: Date())
    }
    
    // MARK: - Timer

    private var timer: BackgroundTimer?
    private var timerQueue = DispatchQueue(label: "ExtensionCertificateRefreshManager.Timer", qos: .background)
    
    private func startTimer(at nextRunTime: Date) {
        timerQueue.async {
            self.timer = BackgroundTimer(runAt: nextRunTime, repeating: self.checkInterval, queue: self.timerQueue) { [weak self] in
                self?.timerFired()
            }
            log.info("Timer setup for \(nextRunTime)", category: .userCert)
        }
    }
    
    @objc private func timerFired() {
        guard let certificate = vpnAuthenticationStorage.getStoredCertificate() else {
            log.info("No current certificate. Starting refresh.", category: .userCert)
            refreshCertificate()
            return
        }
        let nextRefreshTime = certificate.refreshTime.addingTimeInterval(refreshEarlierBy)
        log.info("Current cert is valid until: \(certificate.validUntil); refresh time: \(certificate.refreshTime). Will be refreshed after: \(nextRefreshTime).", category: .userCert)

        guard nextRefreshTime <= Date() else {
            return
        }

        log.info("Starting certificate refresh.", category: .userCert)
        refreshCertificate()
    }
    
    private func refreshCertificate() {
        guard let currentKeys = vpnAuthenticationStorage.getStoredKeys() else {
            log.error("Can't load current keys. Nothing to refresh. Giving up.", category: .userCert, event: .refreshError)
            return
        }
        
        let features = vpnAuthenticationStorage.getStoredCertificateFeatures()
        apiService.refreshCertificate(publicKey: currentKeys.publicKey.derRepresentation, features: features) { result in
            switch result {
            case .success(let certificate):
                log.debug("Certificate refreshed. Saving to keychain.", category: .userCert)
                self.vpnAuthenticationStorage.store(certificate: VpnCertificateWithFeatures(certificate: certificate, features: features))
                
            case .failure(let error):
                log.error("Failed to refresh certificate through API: \(error)", category: .userCert)
            }
        }
    }

}

private final class BackgroundTimer {
    
    private let timerSource: DispatchSourceTimer
    private let closure: () -> Void
    
    private enum State {
        case suspended
        case resumed
    }
    private var state: State = .resumed

    init(runAt nextRunTime: Date, repeating: Double, queue: DispatchQueue, _ closure: @escaping () -> Void) {
        self.closure = closure
        timerSource = DispatchSource.makeTimerSource(queue: queue)
        
        timerSource.schedule(deadline: .now() + .seconds(Int(nextRunTime.timeIntervalSinceNow)), repeating: repeating, leeway: .seconds(10)) // We have at least minute before app (if in foreground) may start refreshing cert. So 10 seconds later is ok.
        timerSource.setEventHandler { [weak self] in
            if repeating <= 0 { // Timer should not repeat, so lets suspend it
                self?.timerSource.suspend()
                self?.state = .suspended
            }
            self?.closure()
        }
        timerSource.resume()
        state = .resumed
    }
    
    deinit {
        timerSource.setEventHandler {}
        if state == .suspended {
            timerSource.resume()
        }
        timerSource.cancel()
    }
    
}
