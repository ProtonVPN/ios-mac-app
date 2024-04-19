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
import Dependencies
import LegacyCommon
import PMLogger
import VPNShared

protocol HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel
}

extension DependencyContainer: HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel {
        return HelpMenuViewModel(factory: self)
    }
}

class HelpMenuViewModel {
    
    typealias Factory = VpnManagerFactory
                        & NavigationServiceFactory
                        & VpnKeychainFactory
                        & CoreAlertServiceFactory
                        & SystemExtensionManagerFactory
                        & PropertiesManagerFactory
                        & LogFileManagerFactory
                        & LogContentProviderFactory
                        & AuthKeychainHandleFactory
                        & AppInfoFactory
                        & WindowServiceFactory
                        & VpnAuthenticationStorageFactory
    private var factory: Factory
    
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var logFileManager: LogFileManager = factory.makeLogFileManager()
    private lazy var logContentProvider: LogContentProvider = factory.makeLogContentProvider()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var vpnAuthenticationStorage: VpnAuthenticationStorageSync = factory.makeVpnAuthenticationStorage()

    init(factory: Factory) {
        self.factory = factory
    }

    func logDebugInfoString() {
        log.info("Build info: \(factory.makeAppInfo().debugInfoString)")
    }
    
    func openLogsFolderAction() {
        logDebugInfoString()
        navService.openLogsFolder()
    }
    
    func openWGVpnLogsFolderAction() {
        // Save log to file
        logContentProvider.getLogData(for: .wireguard).loadContent { logContent in
            self.logFileManager.dump(logs: logContent, toFile: AppConstants.Filenames.wireGuardLogFilename)
            self.navService.openLogsFolder(filename: AppConstants.Filenames.wireGuardLogFilename)
        }
    }

    func systemExtensionTutorialAction() {
        windowService.openSystemExtensionGuideWindow(cancelledHandler: {})
    }
    
    func selectClearApplicationData() {
        alertService.push(alert: ClearApplicationDataAlert { [self] in
            self.vpnManager.disconnect { [self] in
                self.clearAllDataAndTerminate()
            }
        })
    }
    
    func openReportBug() {
        logDebugInfoString()
        navService.showReportBug()
    }

    private func clearAllDataAndTerminate() {
        if self.systemExtensionManager.uninstallAll(userInitiated: true, timeout: nil) == .timedOut {
            log.error("Timed out waiting for sysext uninstall, proceeding to clear app data", category: .sysex)
        }

        // keychain
        self.vpnKeychain.clear()
        self.authKeychain.clear()

        self.vpnAuthenticationStorage.deleteCertificate()
        self.vpnAuthenticationStorage.deleteKeys()

        // app data
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            @Dependency(\.defaultsProvider) var provider
            let defaults = provider.getDefaults()
            if let domain = defaults.persistentDomain(forName: bundleIdentifier) {
                for key in domain.keys {
                    defaults.removeObject(forKey: key)
                }
                defaults.removePersistentDomain(forName: bundleIdentifier)
            }
        }


        let itemsToDelete = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path, // legacy: old server storage
            AppConstants.FilePaths.sandbox, // legacy
            AppConstants.FilePaths.starterSandbox // legacy
        ]

        itemsToDelete.compactMap { $0 }.forEach { path in
            deleteItems(atPath: path)
        }

        nukeServerDatabase()

        // vpn profile
        self.vpnManager.removeConfigurations { _ in
            // quit app
            DispatchQueue.main.async {
                NSApplication.shared.terminate(self)
            }
        }
    }

    private func deleteItems(atPath path: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            log.error(
                "Failed to delete item",
                category: .persistence,
                metadata: ["path": "\(path)", "error": "\(error)"]
            )
        }
    }

    private func nukeServerDatabase() {
        @Dependency(\.databaseConfiguration) var config
        guard case .physical(let path) = config.databaseType else {
            assertionFailure("We should be using a persistence database in the app target")
            return
        }

        do {
            @Dependency(\.serverRepository) var repository
            try repository.closeConnection()
        } catch {
            log.error("Failed to close database connection", category: .persistence, metadata: ["error": "\(error)"])
        }

        // Let's try to delete the database file even if we failed to close the database connection
        deleteItems(atPath: path)
    }
}
