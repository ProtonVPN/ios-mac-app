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
import Domain
import LegacyCommon
import PMLogger
import Settings
import SwiftUI
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
    typealias Factory = CoreAlertServiceFactory
        & NavigationServiceFactory
        & WindowServiceFactory
    private var factory: Factory

    @Dependency(\.vpnAuthenticationStorage) private var vpnAuthenticationStorage
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    @Dependency(\.systemExtensionsCoordinator) private var systemExtensionsCoordinator
    @Dependency(\.logFileManager) private var logFileManager
    @Dependency(\.logContentProvider) private var logContentProvider

    init(factory: Factory) {
        self.factory = factory
    }

    func logDebugInfoString() {
        @Dependency(\.appInfo) var appInfo
        log.info("Build info: \(appInfo.debugInfoString)")
    }

    func openLogsFolderAction() {
        navService.openLogsFolder()
    }

    func openWGVpnLogsFolderAction() {
        // Save log to file
        logContentProvider.getLogData(for: .protun).loadContent { logContent in
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

    #if DEBUG
        func presentDebugScreen() {
            let environmentsView = EnvironmentSelectorDesktopView(continueHandler: {})

            let hostingView = NSHostingView(rootView: environmentsView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            let viewController = NSViewController()
            viewController.view = hostingView
            windowService.presentKeyModal(viewController: viewController, activatingApp: true)
        }
    #endif

    func selectClearApplicationData() {
        alertService.push(alert: ClearApplicationDataAlert { [weak self] in
            guard let self else { return }
            connectionCommandClient.send(.disconnect(.auto, completion: { [weak self] in
                guard let self else { return }
                connectionCommandClient.send(.clearConnectionData(completion: { [weak self] in
                    guard let self else { return }
                    Task {
                        await self.clearAllDataAndTerminate()
                    }
                }))
            }))
        })
    }

    func openReportBug() {
        logDebugInfoString()
        navService.showReportBug()
    }

    private func clearAllDataAndTerminate() async {
        log.info("Starting application data clear sequence", category: .app)

        AppEvent.clearingApplicationData.post()

        await systemExtensionsCoordinator.uninstallAll(origin: .clearData, userInitiated: true)

        // keychain
        vpnKeychain.clear()
        @Dependency(\.authKeychain) var authKeychain
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

        log.info("VPN configurations cleanup requested through connection layer", category: .app)

        // Now nuke the database after VPN configurations are removed
        nukeServerDatabase()

        await MainActor.run {
            log.info("Application data cleared, terminating the app", category: .app)
            NSApplication.shared.terminate(self)
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
