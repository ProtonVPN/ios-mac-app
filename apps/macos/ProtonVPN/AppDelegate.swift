//
//  AppDelegate.swift
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

import ServiceManagement
import vpncore
import ProtonCore_Services
import ProtonCore_Log
import ProtonCore_UIFoundations
import Logging

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var protonVpnMenu: ProtonVpnMenuController!
    @IBOutlet weak var profilesMenu: ProfilesMenuController!
    @IBOutlet weak var helpMenu: HelpMenuController!
    @IBOutlet weak var statusMenu: StatusMenuWindowController!
    
    fileprivate let container = DependencyContainer()
    lazy var navigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var systemExtensionStateCheck = container.makeSystemExtensionsStateCheck()
    private lazy var appInfo: AppInfo = container.makeAppInfo()
    
    private var notificationManager: NotificationManagerProtocol!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {        
        setupCoreIntegration()
        setupLogsForApp()
        log.info("Starting app version \(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))", category: .app, event: .processStart)
        
        self.checkMigration()
        migrateIfNeeded {
            self.setNSCodingModuleName()
            self.setupDebugHelpers()
            
            SentryHelper.setupSentry(dsn: ObfuscatedConstants.sentryDsnmacOS)
            
            AppLaunchRoutine.execute(propertiesManager: self.propertiesManager)
            
            _ = self.container.makeAuthApiService() // Prepare auth service for 401 response on the first request
            self.protonVpnMenu.update(with: self.container.makeProtonVpnMenuViewModel())
            self.profilesMenu.update(with: self.container.makeProfilesMenuViewModel())
            self.helpMenu.update(with: self.container.makeHelpMenuViewModel())
            self.statusMenu.update(with: self.container.makeStatusMenuWindowModel())
            self.container.makeWindowService().setStatusMenuWindowController(self.statusMenu)
            self.notificationManager = self.container.makeNotificationManager()
            self.container.makeMaintenanceManagerHelper().startMaintenanceManager()
            _ = self.container.makeUpdateManager() // Load update manager so it has a chance to update xml url
            _ = self.container.makeDynamicBugReportManager() // Loads initial bug report config and sets up a timer to refresh it daily.
            
            if self.startedAtLogin() {
                DistributedNotificationCenter.default().post(name: Notification.Name("killMe"), object: Bundle.main.bundleIdentifier!)
            }

            self.checkSystemExtension()

            self.container.makeVpnManager().whenReady(queue: DispatchQueue.main) {
                self.navigationService.launched()
            }
        }
    }
    
    private func setupDebugHelpers() {
        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "15 minutes"
        #endif
    }
    
    func applicationShouldHandleReopen(_ theApplication: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return navigationService.handleApplicationReopen(hasVisibleWindows: flag)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        log.info("applicationDidBecomeActive", category: .os)
        container.makeAppSessionRefreshTimer().start(now: true) // refresh data if time passed
        // Refresh API announcements
        if propertiesManager.featureFlags.pollNotificationAPI, AuthKeychain.fetch() != nil {
            self.container.makeAnnouncementRefresher().refresh()
        }

    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        log.info("applicationShouldTerminate", category: .os)
        Storage.userDefaults().set(500, forKey: "NSInitialToolTipDelay")
        return navigationService.handleApplicationShouldTerminate()
    }
    
    private func migrateIfNeeded(completion: @escaping (() -> Void)) {
        do {
            try FileManager.default.copyItem(atPath: AppConstants.FilePaths.sandbox, toPath: AppConstants.FilePaths.userDefaults)
            
            // Restart the app so that it picks up the copied user defaults instead of creating a new one
            restartApp()
        } catch let error as NSError {
            switch error.code {
            case NSFileReadNoSuchFileError:
                log.info("No file to migrate", category: .app)
            case NSFileWriteFileExistsError:
                log.info("Migration not required", category: .app)
            default:
                log.error("Migration error code: \((error as NSError).code)", category: .app) // don't show full error text because it can contain system username
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func restartApp() {
        log.info("Restart app", category: .os)
        let appPath = Bundle.main.bundleURL.absoluteString
        let relaunchAppProcess = Process()
        relaunchAppProcess.launchPath = "/usr/bin/open"
        relaunchAppProcess.arguments = [appPath]
        relaunchAppProcess.launch()
        exit(0)
    }
    
    private func setNSCodingModuleName() {
        // Force all encoded objects to be decoded and encoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: NSStringFromClass(type(of: self)).components(separatedBy: ".").first!)
    }
    
    private func startedAtLogin() -> Bool {
        let launcherAppIdentifier = "ch.protonvpn.ProtonVPNStarter"
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == launcherAppIdentifier {
            return true
        }
        return false
    }
    
    private func checkSystemExtension() {
        // only install the extension if OpenVPN/WireGuard is selected or Smart Protocol is enabled
        let needsInstallExtension: Bool
        let vpnProtocol = propertiesManager.vpnProtocol
        switch vpnProtocol {
        case .ike:
            needsInstallExtension = propertiesManager.smartProtocol
        case .openVpn:
            needsInstallExtension = true
        case .wireGuard:
            needsInstallExtension = true
        }
        guard needsInstallExtension else {
            log.debug("No need to install system extension (protocol is \(vpnProtocol.localizedString)), bailing.", category: .sysex)

            return
        }

        systemExtensionStateCheck.startCheckAndInstallIfNeeded { result in
            if case .failure = result {
                self.propertiesManager.vpnProtocol = .ike
                self.propertiesManager.smartProtocol = false
            }
        }
    }
    
    private func setupLogsForApp() {
        LoggingSystem.bootstrap {_ in
            return MultiplexLogHandler([
                ConsoleLogHandler(),
                FileLogHandler(self.container.makeLogFileManager().getFileUrl(named: AppConstants.Filenames.appLogFilename))
            ])
        }
    }
}

// MARK: - Migration
extension AppDelegate {
    fileprivate func checkMigration() {
        container.makeMigrationManager()
            .addCheck("1.7.1") { version, completion in
                // Restart the connection, because whole vpncore was upgraded between version 1.6.0 and 1.7.0
                log.info("App was updated to version 1.7.1 from version \(version)", category: .appUpdate)
                
                self.reconnectWhenPossible()
                completion(nil)
            }
            .addCheck("2.0.0") { version, completion in
                // Restart the connection, to enable native KS (if needed)
                log.info("App was updated to version 2.0.0 from version \(version)", category: .appUpdate)
                
                guard self.container.makePropertiesManager().killSwitch else {
                    completion(nil)
                    return
                }
                
                self.reconnectWhenPossible()
                completion(nil)                
            }
            .migrate { _ in
                // Migration complete
            }
    }
    
    private func reconnectWhenPossible() {
        var appStateManager = self.container.makeAppStateManager()
        
        appStateManager.onVpnStateChanged = { newState in
            if newState != .invalid {
                appStateManager.onVpnStateChanged = nil
            }
            
            guard case .connected = newState else {
                return
            }
            
            appStateManager.disconnect {
                self.container.makeVpnGateway().quickConnect()
            }
        }
    }
}

extension AppDelegate {
    private func setupCoreIntegration() {
        ColorProvider.brand = .vpn
        
        let trusKitHelper = container.makeTrustKitHelper()
        PMAPIService.trustKit = trusKitHelper?.trustKit
        PMAPIService.noTrustKit = trusKitHelper?.trustKit == nil

        ProtonCore_Log.PMLog.callback = { (message, level) in
            switch level {
            case .debug, .info, .trace, .warn:
                log.debug("[Core] \(message)", category: .app)
            case .error, .fatal:
                log.error("[Core] \(message)", category: .app, source: "Core")
            }
        }
    }
}
