//
//  HelpMenuViewModel.swift
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

import Cocoa
import vpncore

protocol HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel
}

extension DependencyContainer: HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel {
        return HelpMenuViewModel(factory: self)
    }
}

class HelpMenuViewModel {
    
    typealias Factory = VpnManagerFactory & NavigationServiceFactory & VpnKeychainFactory & CoreAlertServiceFactory & SystemExtensionManagerFactory
    private var factory: Factory
    
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func openLogsFolderAction() {
        navService.openLogsFolder()
    }
    
    func openOpenVpnLogsFolderAction() {
        // Save log to file
        vpnManager.logsContent(for: .openVpn(.undefined)) { logs in
            let content = logs ?? ""
            PMLog.D(content, overwrite: true, filename: AppConstants.Filenames.openVpnLogFilename)
        }
                
        navService.openLogsFolder(filename: AppConstants.Filenames.openVpnLogFilename)
    }
    
    func selectClearApplicationData() {
        alertService.push(alert: ClearApplicationDataAlert { [self] in
            self.vpnManager.disconnect { [self] in
                self.clearAllDataAndTerminate()
            }
        })
    }
    
    func openReportBug() {
        navService.showReportBug()
    }
    
    private func clearAllDataAndTerminate() {
        
        // System Extension
        systemExtensionManager.requestExtensionUninstall { error in
            
            // keychain
            self.vpnKeychain.clear()
            AuthKeychain.clear()

            // app data
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                Storage.userDefaults().removePersistentDomain(forName: bundleIdentifier)
                Storage.userDefaults().synchronize()
            }

            do {
                try FileManager.default.removeItem(atPath: AppConstants.FilePaths.sandbox) // legacy
            } catch {}
            do {
                try FileManager.default.removeItem(atPath: AppConstants.FilePaths.starterSandbox) // legacy
            } catch {}

            // vpn profile
            self.vpnManager.removeConfigurations(completionHandler: nil)

            // quit
            DispatchQueue.main.async {
                NSApplication.shared.terminate(self)
            }
            
        }
    }
}
