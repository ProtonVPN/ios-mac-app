//
//  CertificateRefreshManager.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit

/// Class for making sure there is always up-to-date certificate.
/// After running `planNextRefresh()` for the first time, will start Timer to run a minute before certificates `RefreshTime`.
final class CertificateRefreshManager {
    
    /// Last time interval that was waited before retry on API error. Will be increased by `nextRetryBackoff()`.
    private var lastRetryInterval: TimeInterval = 10
    
    /// Certificate will be refreshed this number of seconds earlier than requested to lessen the possibility of refreshing it by both app and extension.
    private var refreshEarlierBy: TimeInterval = -60
    
    private let vpnAuthenticationStorage: VpnAuthenticationStorage = VpnAuthenticationKeychain(accessGroup: WGConstants.keychainAccessGroup)
    private let certificateRefreshRequest = CertificateRefreshRequest()
    private var timer: Timer?
    
    func planNextRefresh() {
        guard let certificate = vpnAuthenticationStorage.getStoredCertificate() else {
            wg_log(.info, message: "No current certificate, will try to generate new certificate right now.")
            startTimer(at: Date())
            return
        }

        var nextRefreshTime = certificate.refreshTime.addingTimeInterval(refreshEarlierBy)

        if nextRefreshTime < Date() {
            wg_log(.info, message: "Current certificate should've been refreshed at \(certificate.refreshTime) (\(refreshEarlierBy)s). Starting refresh right now.")
            nextRefreshTime = Date()
        }
        
        startTimer(at: nextRefreshTime)
    }
    
    // MARK: -
    
    private func startTimer(at nextRunTime: Date) {
        timer?.invalidate()
        let timer = Timer(fireAt: nextRunTime, interval: 0, target: self, selector: #selector(timerFired), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        wg_log(.info, message: "Timer setup for \(nextRunTime)")
    }
    
    @objc private func timerFired() {
        if let certificate = vpnAuthenticationStorage.getStoredCertificate() {
            wg_log(.info, message: "Current cert: \(certificate)")
            
            let nextRefreshTime = certificate.refreshTime.addingTimeInterval(refreshEarlierBy)
            guard nextRefreshTime <= Date() else {
                wg_log(.info, message: "Current certificate should be refreshed not earlier than  \(certificate.refreshTime) (\(refreshEarlierBy)s). Postponing refresh until that time.")
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
        
        certificateRefreshRequest.refresh(publicKey: currentKeys.publicKey.derRepresentation) { result in
            switch result {
            case .success(let certificate):
                wg_log(.info, message: "Certificate refreshed. Saving to keychain.")
                self.vpnAuthenticationStorage.store(certificate: certificate)
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
