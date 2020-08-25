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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var protonVpnMenu: ProtonVpnMenuController!
    @IBOutlet weak var profilesMenu: ProfilesMenuController!
    @IBOutlet weak var helpMenu: HelpMenuController!
    @IBOutlet weak var statusMenu: StatusMenuWindowController!
    
    fileprivate let container = DependencyContainer()
    lazy var navigationService = container.makeNavigationService()
    
    private var notificationManager: NotificationManagerProtocol!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        PMLog.D("Starting app version \(ApiConstants.bundleShortVersion) (\(ApiConstants.bundleVersion)) ")
        self.checkMigration()
        migrateIfNeeded { [unowned self] in
            self.setNSCodingModuleName()
            
            #if RELEASE // to avoid issues with bitcode uploads not being reliable during development
            PMLog.setupSentry(dsn: ObfuscatedConstants.sentryDsn)
            #endif
            
            AppLaunchRoutine.execute()
            
            _ = self.container.makeAuthApiService() // Prepare auth service for 401 response on the first request
            self.protonVpnMenu.update(with: self.container.makeProtonVpnMenuViewModel())
            self.profilesMenu.update(with: self.container.makeProfilesMenuViewModel())
            self.helpMenu.update(with: self.container.makeHelpMenuViewModel())
            self.statusMenu.update(with: self.container.makeStatusMenuWindowModel())
            self.container.makeWindowService().setStatusMenuWindowController(self.statusMenu)
            self.notificationManager = self.container.makeNotificationManager()
            self.container.makeMaintenanceManager().observeCurrentServerState(
                every: AppConstants.Time.maintenanceCheckTimeInterval,
                repeats: true,
                callback: nil)
            
            if self.startedAtLogin() {
                DistributedNotificationCenter.default().post(name: Notification.Name("killMe"), object: Bundle.main.bundleIdentifier!)
            }
        
            self.navigationService.launched()
        }
    }
    
    func applicationShouldHandleReopen(_ theApplication: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return navigationService.handleApplicationReopen(hasVisibleWindows: flag)
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        navigationService.appSessionManager.scheduleRefreshes(now: true)
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        navigationService.appSessionManager.stopRefreshingIfInactive()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
                PMLog.D("No file to migrate")
            case NSFileWriteFileExistsError:
                PMLog.D("Migration not required")
            default:
                PMLog.ET("Migration error code: \((error as NSError).code)", level: .error) // don't show full error text because it can contain system username
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func restartApp() {
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
}

// MARK: - Migration
extension AppDelegate {
    fileprivate func checkMigration() {
        container.makeMigrationManager().addCheck("1.7.1") { version, completion in
            // Restart the connection, because whole vpncore was upgraded between version 1.6.0 and 1.7.0
            PMLog.D("App was updated to version 1.7.1 from version " + version)
            let appStateManager = self.container.makeAppStateManager()
            
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
            completion(nil)
        }.migrate { _ in
            //Migration complete
        }
    }
}
