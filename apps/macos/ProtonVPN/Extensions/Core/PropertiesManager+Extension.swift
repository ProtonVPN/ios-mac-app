//
//  PropertiesManager+Extension.swift
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

import Foundation
import ServiceManagement
import LegacyCommon

extension PropertiesManagerProtocol {
    var earlyAccess: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.earlyAccess)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.earlyAccess)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PropertiesManager.earlyAccessNotification, object: newValue)
            }
        }
    }
    
    var unprotectedNetworkNotifications: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.unprotectedNetworkNotifications)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.unprotectedNetworkNotifications)
        }
    }
    
    var rememberLoginAfterUpdate: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.rememberLoginAfterUpdate)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.rememberLoginAfterUpdate)
        }
    }
    
    var startMinimized: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.startMinimized)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.startMinimized)
        }
    }
    
    var startOnBoot: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.startOnBoot)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.startOnBoot)
            self.setLoginItem(enabled: newValue)
        }
    }
    
    var systemNotifications: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.systemNotifications)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.systemNotifications)
        }
    }

    var uninstallSysexesOnTerminate: Bool {
        get {
            return getValue(forKey: AppConstants.UserDefaults.uninstallSysexesOnTerminate)
        }
        set {
            setValue(newValue, forKey: AppConstants.UserDefaults.uninstallSysexesOnTerminate)
        }
    }
    
    func restoreStartOnBootStatus() {
        let enabled = self.startOnBoot
        self.setLoginItem(enabled: enabled)
    }
    
    // MARK: - Private
    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                registerLoginItem()
            } else {
                unregisterLoginItem()
            }
        } else {
            let launcherAppIdentifier = "ch.protonvpn.ProtonVPNStarter"
            if SMLoginItemSetEnabled(launcherAppIdentifier as CFString, enabled) {
                if enabled {
                    log.info("Successfully add login item.", category: .app)
                } else {
                    log.info("Successfully remove login item.", category: .app)
                }
            } else {
                log.error("Failed to add login item.", category: .app)
            }
        }
    }

    @available(macOS 13.0, *)
    private func registerLoginItem() {
        do {
            let service = SMAppService()
            try service.register()
        } catch {
            log.error("Failed to register login item: \(error)", category: .app)
        }
    }

    @available(macOS 13.0, *)
    private func unregisterLoginItem() {
        do {
            let service = SMAppService()
            try service.unregister()
        } catch {
            log.error("Failed to unregister login item: \(error)", category: .app)
        }
    }
}
