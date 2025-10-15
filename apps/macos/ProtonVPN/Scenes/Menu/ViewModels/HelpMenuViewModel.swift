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

import Domain
import PMLogger
import VPNShared

protocol HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel
}

extension DependencyContainer: HelpMenuViewModelFactory {
    func makeHelpMenuViewModel() -> HelpMenuViewModel {
        HelpMenuViewModel(factory: self)
    }
}

class HelpMenuViewModel {
    typealias Factory = AppInfoFactory
        & AuthKeychainHandleFactory
        & CoreAlertServiceFactory
        & LogContentProviderFactory
        & LogFileManagerFactory
        & NavigationServiceFactory
        & SystemExtensionManagerFactory
        & VpnAuthenticationStorageFactory
        & VpnKeychainFactory
        & VpnManagerFactory
        & WindowServiceFactory
    private var factory: Factory

    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    @Dependency(\.propertiesManager) private var propertiesManager
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
        navService.openLogsFolder()
    }

    func openWGVpnLogsFolderAction() {
        // Save log to file
        logContentProvider.getLogData(for: .wireguard).loadContent { logContent in
            self.logFileManager.dump(logs: logContent, toFile: AppConstants.Filenames.wireGuardLogFilename)
            self.navService.openLogsFolder(filename: AppConstants.Filenames.wireGuardLogFilename)
        }
    }

    func openPlutoniumLogsFolderAction() {
        guard VPNFeatureFlagType.plutoniumMacOS.enabled else { return }
        logContentProvider.getLogData(for: .plutonium).loadContent { logContent in
            self.logFileManager.dump(logs: logContent, toFile: AppConstants.Filenames.plutoniumLogFilename)
            self.navService.openLogsFolder(filename: AppConstants.Filenames.plutoniumLogFilename)
        }
    }

    func systemExtensionTutorialAction() {
        windowService.openSystemExtensionGuideWindow(origin: .inAppPrompt([]), cancelledHandler: {})
    }

    func selectClearApplicationData() {
        alertService.push(alert: ClearApplicationDataAlert { [self] in
            vpnManager.disconnect { [self] in
                clearAllDataAndTerminate()
            }
        })
    }

    func openReportBug() {
        logDebugInfoString()
        navService.showReportBug()
    }

    private func clearAllDataAndTerminate() {
        vpnManager.disconnect {}

        AppEvent.clearingApplicationData.post()

        if systemExtensionManager.uninstallAll(userInitiated: true, timeout: nil) == .timedOut {
            log.error("Timed out waiting for sysext uninstall, proceeding to clear app data", category: .sysex)
        }

        // keychain
        vpnKeychain.clear()
        authKeychain.clear(.clearApplicationData)

        let sharedConfigURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: DomainConstants.AppGroups.main)!
        try? FileManager.default.removeItem(at: sharedConfigURL)

        vpnAuthenticationStorage.deleteCertificate()
        vpnAuthenticationStorage.deleteKeys()

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

        nukeServerDatabase()

        // vpn profile
        vpnManager.removeConfigurations { _ in
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
        guard case let .physical(path) = config.databaseType else {
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
