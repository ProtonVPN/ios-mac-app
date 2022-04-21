//
//  CertificateRefreshManager.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import os.log

/// Class for making sure there is always up-to-date certificate.
/// After running `planNextRefresh()` for the first time, will start Timer to run a minute before certificates `RefreshTime`.
final class ExtensionCertificateRefreshManager {
    
    /// Last time interval that was waited before retry on API error. Will be increased by `nextRetryBackoff()`.
    private var lastRetryInterval: TimeInterval = 10
    
    /// Certificate will be refreshed this number of seconds earlier than requested to lessen the possibility of refreshing it by both app and extension.
    private var refreshEarlierBy: TimeInterval = -60
    
    private let vpnAuthenticationStorage: VpnAuthenticationStorage = VpnAuthenticationKeychain(accessGroup: WGConstants.keychainAccessGroup, storage: Storage())
    private let apiService = ExtensionAPIService(storage: Storage())
    
    func planNextRefresh() {
        guard let certificate = vpnAuthenticationStorage.getStoredCertificate() else {
            wg_log(.info, message: "No current certificate, will try to generate new certificate right now.")
            startTimer(at: Date())
            return
        }

        var nextRefreshTime = certificate.refreshTime.addingTimeInterval(refreshEarlierBy)

        if nextRefreshTime < Date() {
            wg_log(.info, message: "Current certificate should've been refreshed at \(nextRefreshTime) (\(certificate.refreshTime) - \(refreshEarlierBy)s). Starting refresh right now.")
            nextRefreshTime = Date()
        }
        
        startTimer(at: nextRefreshTime)
    }
    
    // MARK: - Timer

    private var timer: BackgroundTimer?
    private var timerQueue = DispatchQueue(label: "ExtensionCertificateRefreshManager.Timer", qos: .background)
    
    private func startTimer(at nextRunTime: Date) {
        timerQueue.async {
            self.timer = BackgroundTimer(runAt: nextRunTime, queue: self.timerQueue) { [weak self] in
                self?.timerFired()
            }
            wg_log(.info, message: "Timer setup for \(nextRunTime)")
        }
    }
    
    @objc private func timerFired() {
        if let certificate = vpnAuthenticationStorage.getStoredCertificate() {
            wg_log(.info, message: "Current cert is valid until: \(certificate.validUntil)")
            
            let nextRefreshTime = certificate.refreshTime.addingTimeInterval(refreshEarlierBy)
            guard nextRefreshTime <= Date() else {
                wg_log(.info, message: "Current certificate should be refreshed not earlier than \(nextRefreshTime) (\(certificate.refreshTime) - \(refreshEarlierBy)s). Postponing refresh until that time.")
                planNextRefresh()
                return
            }
            
        } else {
            wg_log(.info, message: "No current certificate")
        }                
        
        refreshCertificate()
    }
    
    private func refreshCertificate() {
        guard let currentKeys = vpnAuthenticationStorage.getStoredKeys() else {
            wg_log(.default, message: "Can't load current keys. Nothing to refresh.")
            return
        }
        
        let features = vpnAuthenticationStorage.getStoredCertificateFeatures()
        apiService.refreshCertificate(publicKey: currentKeys.publicKey.derRepresentation, features: features) { result in
            switch result {
            case .success(let certificate):
                wg_log(.info, message: "Certificate refreshed. Saving to keychain.")
                self.vpnAuthenticationStorage.store(certificate: VpnCertificateWithFeatures(certificate: certificate, features: features))
                self.planNextRefresh()
                
            case .failure(let error):
                wg_log(.error, message: "Failed to refresh certificate through API: \(error)")
                let delay = self.nextRetryBackoff()
                wg_log(.error, message: "Will retry in \(delay) seconds")
                self.startTimer(at: Date().addingTimeInterval(delay))
            }
        }
    }
    
    // MARK: -
    
    private func nextRetryBackoff() -> TimeInterval {
        lastRetryInterval *= 2
        return lastRetryInterval
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
    
    init(runAt nextRunTime: Date, queue: DispatchQueue, _ closure: @escaping () -> Void) {
        self.closure = closure
        timerSource = DispatchSource.makeTimerSource(queue: queue)
        
        timerSource.schedule(deadline: .now() + .seconds(Int(nextRunTime.timeIntervalSinceNow)), repeating: .infinity, leeway: .seconds(10)) // We have at least minute before app (if in foreground) may start refreshing cert. So 10 seconds later is ok.
        timerSource.setEventHandler { [weak self] in
            self?.timerSource.suspend()
            self?.state = .suspended
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
