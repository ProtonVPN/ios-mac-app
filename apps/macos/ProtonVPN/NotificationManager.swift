//
//  NotificationManager.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import vpncore

import Foundation

protocol NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManager
}

class NotificationManager: NSObject {
    
    private let delayBeforeDismissing: TimeInterval = 5
    private let appStateManager: AppStateManager
    private let appSessionManager: AppSessionManager
    private let firewallManager: FirewallManager
    
    private var nonTransientState: AppState = .disconnected
    
    private var firstTimeConnection = false
    
    private var shouldShowNotification: Bool {
        return appSessionManager.sessionStatus == .established && Storage.userDefaults().bool(forKey: AppConstants.UserDefaults.systemNotifications)
    }
    
    init(appStateManager: AppStateManager, appSessionManager: AppSessionManager, firewallManager: FirewallManager) {
        self.appStateManager = appStateManager
        self.appSessionManager = appSessionManager
        self.firewallManager = firewallManager
        
        super.init()
        
        setNonTransientState(state: appStateManager.state)
        NSUserNotificationCenter.default.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(appStateChanged),
                                               name: appStateManager.stateChange, object: nil)
    }
    
    @objc private func appStateChanged(_ notification: Notification) {
        if let newState = notification.object as? AppState {
            if case AppState.connecting(_) = newState {
                firstTimeConnection = !PropertiesManager().hasConnected // prevents disconnected notification showing on first connection
            } else if case AppState.connected(_) = newState, let server = appStateManager.activeConnection()?.server, shouldShowNotification {
                fire(connectedNotification(for: server))
            } else if case AppState.disconnected = newState, case AppState.connected(_) = nonTransientState, shouldShowNotification, !firstTimeConnection {
                disconnectedNotification { [weak self] (notification) in
                    self?.fire(notification)
                }
            }
            
            setNonTransientState(state: newState)
        }
    }
    
    private func setNonTransientState(state: AppState) {
        switch state {
        case .connected, .disconnected, .aborted, .error:
            self.nonTransientState = state
        default:
            break
        }
    }
    
    private func connectedNotification(for server: ServerModel) -> NSUserNotification {
        let notification = NSUserNotification()
        notification.title = "ProtonVPN " + LocalizedString.connected
        notification.subtitle = connectSubtitle(forServer: server)
        notification.informativeText = connectInformativeText(forServer: server)
        notification.hasActionButton = false
        return notification
    }
    
    private func disconnectedNotification(completion: @escaping (NSUserNotification) -> Void) {
        let notification = NSUserNotification()
        notification.hasActionButton = false
        notification.title = "ProtonVPN " + LocalizedString.disconnected
        appStateManager.isOnDemandEnabled { [weak self] enabled in
            guard enabled else { return completion(notification) }
            if PropertiesManager().killSwitch {
                self?.firewallManager.isProtonFirewallEnabled { (enabled) in
                    notification.subtitle = enabled ? LocalizedString.killSwitchBlockingConnection : LocalizedString.alwaysOnWillReconnect
                    completion(notification)
                }
            } else {
                notification.subtitle = LocalizedString.alwaysOnWillReconnect
                completion(notification)
            }
        }
    }
    
    private func connectSubtitle(forServer server: ServerModel) -> String {
        if server.isSecureCore {
            return server.entryCountry + " > " + server.exitCountry + " > " + server.name
        } else {
            return server.country + " > " + server.name
        }
    }
    
    private func connectInformativeText(forServer server: ServerModel) -> String {
        return String(format: LocalizedString.ipValue, appStateManager.activeConnection()?.serverIp.entryIp ?? LocalizedString.unavailable)
    }
    
    private func fire(_ notification: NSUserNotification) {
        NSUserNotificationCenter.default.deliver(notification)
        NSUserNotificationCenter.default.perform(#selector(NSUserNotificationCenter.removeDeliveredNotification(_:)),
                                                 with: notification,
                                                 afterDelay: delayBeforeDismissing)
    }
}

extension NotificationManager: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

// MARK: - Public

extension NotificationManager {
    func displayServerGoingOnMaintenance() {
        let notification = NSUserNotification()
        notification.title = LocalizedString.onMaintenanceDetectedTitle
        notification.subtitle = LocalizedString.onMaintenanceDetectedSubtitle
        notification.informativeText = LocalizedString.onMaintenanceDetectedDescription
        notification.hasActionButton = false
        fire(notification)
    }
}
