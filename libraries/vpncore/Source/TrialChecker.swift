//
//  TrialChecker.swift
//  vpncore - Created on 26.06.19.
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

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

public protocol TrialCheckerFactory {
    func makeTrialChecker() -> TrialChecker
}

public class TrialChecker {
    
    public static let trialExpired = Notification.Name("ProfileStorageTrialExpired")
    
    public typealias Factory = PropertiesManagerFactory & VpnGatewayFactory & CoreAlertServiceFactory & VpnKeychainFactory & TrialServiceFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var trialService: TrialService = factory.makeTrialService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    
    private var trialEndTimer: Timer?
    
    private var credentials: VpnCredentials?
    
    public init(factory: Factory) {
        self.factory = factory

        NotificationCenter.default.addObserver(self, selector: #selector(vpnCredentialsChanged), name: VpnKeychain.vpnCredentialsChanged, object: nil)
        
        vpnCredentialsChanged()
    }
    
    deinit {
        endTrialEndTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func vpnCredentialsChanged() {
        do {
            endTrialEndTimer()
            let credentials = try vpnKeychain.fetch()
            self.credentials = credentials
            
            if !credentials.isDelinquent {
                if credentials.accountPlan == .trial {
                    let expiration = credentials.expirationTime
                    if expiration.timeIntervalSince1970 < 0.1 && !propertiesManager.trialWelcomed {
                        trialService.presentTrialWelcomeViewController(expiration: expiration)
                        propertiesManager.trialWelcomed = true
                    } else if expiration > Date() && expiration < Date(timeInterval: 60 * 60 * 24 * 2, since: Date()) && // trial has less than 2 days remaining
                        !propertiesManager.warnedTrialExpiring {
                        trialService.presentTrialWelcomeViewController(expiration: expiration)
                        propertiesManager.warnedTrialExpiring = true
                    }
                    
                    startTrialEndTimer(credentials: credentials)
                    
                } else if propertiesManager.lastUserAccountPlan == .trial && credentials.accountPlan == .free {
                    if !propertiesManager.warnedTrialExpired {
                        trialService.presentTrialExpiredViewController()
                        propertiesManager.warnedTrialExpired = true
                    }
                    
                    if vpnGateway.activeServerType == .secureCore {
                        disableSecureCore()
                    }
                }
            }
            
            propertiesManager.lastUserAccountPlan = credentials.accountPlan
        } catch {}
    }
    
    private func disableSecureCore() {
        vpnGateway.disconnect()
        vpnGateway.changeActiveServerType(.standard)
    }
    
    /// Disconnect from VPN when trial ends
    private func startTrialEndTimer(credentials: VpnCredentials) {
        let expiration = credentials.expirationTime
        guard expiration.timeIntervalSinceNow > 0 else { return }
        
        endTrialEndTimer()
        
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(checkTrialEnded), name: UIApplication.didBecomeActiveNotification, object: nil)
        #elseif canImport(Cocoa)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(checkTrialEnded), name: NSWorkspace.didWakeNotification, object: nil)
        #endif
        
        trialEndTimer = Timer(fire: expiration, interval: 0, repeats: false, block: { [checkTrialEnded] timer in
            checkTrialEnded()
        })
        RunLoop.main.add(trialEndTimer!, forMode: .common)
    }
    
    private func endTrialEndTimer() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #elseif canImport(Cocoa)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        #endif
        trialEndTimer?.invalidate()
        trialEndTimer = nil
    }
    
    @objc private func checkTrialEnded() {
        guard let expiration = credentials?.expirationTime,
            expiration.timeIntervalSinceNow <= 0 else { return }
        
        vpnGateway.disconnect()
        NotificationCenter.default.post(name: TrialChecker.trialExpired, object: nil)
    }
    
}
