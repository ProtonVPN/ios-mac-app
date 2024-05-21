//
//  NavigationService.swift
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
import os

import ComposableArchitecture

import CommonNetworking
import Ergonomics
import PMLogger
import LegacyCommon
import VPNShared


protocol NavigationServiceFactory {
    func makeNavigationService() -> NavigationService
}

final class NavigationService {

    typealias Factory = HelpMenuViewModelFactory
        & PropertiesManagerFactory
        & WindowServiceFactory
        & VpnKeychainFactory
        & AppStateManagerFactory
        & AppSessionManagerFactory
        & CoreAlertServiceFactory
        & ReportBugViewModelFactory
        & NavigationServiceFactory
        & UpdateManagerFactory
        & ProfileManagerFactory
        & SystemExtensionManagerFactory
        & VpnGatewayFactory
        & VpnProtocolChangeManagerFactory
        & VpnManagerFactory
        & VpnStateConfigurationFactory
        & SystemExtensionManagerFactory
        & LogFileManagerFactory
        & NATTypePropertyProviderFactory
        & SafeModePropertyProviderFactory
        & ProtonReachabilityCheckerFactory
        & NetworkingFactory
        & SessionServiceFactory
        & AuthKeychainHandleFactory
        & TelemetrySettingsFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    
    var appHasPresented = false
    var isSystemLoggingOff = false

    private var notificationTokens: [NotificationToken] = []
    
    init(_ factory: Factory) { // be careful not to initialize anything that could create a cycle if that object were to use the NavigationService (e.g. AppStateManager)
        self.factory = factory
    }
    
    func launched() {
        notificationTokens.append(NotificationCenter.default.addObserver(for: SessionChanged.self, object: appSessionManager, handler: sessionChanged))
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(powerOff(_:)),
                                                          name: NSWorkspace.willPowerOffNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sessionSwitchedOut(_:)), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sessionBecameActive(_:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        
        if propertiesManager.startMinimized {
            attemptSilentLogIn()
        } else {
            showLogIn()
        }
        
    }
    
    @objc private func sessionSwitchedOut(_ notification: NSNotification) {
        log.debug("User session did resign active", category: .app)
        vpnGateway.disconnect()
    }
    
    @objc private func sessionBecameActive(_ notification: NSNotification) {
        log.debug("User session did become active", category: .app)
        guard vpnGateway.connection == .disconnected else {
            return
        }

        guard let username = authKeychain.username else {
            return
        }

        guard propertiesManager.getAutoConnect(for: username).enabled else {
            return
        }

        vpnGateway.autoConnect()
    }
#if REDESIGN
    var sendAction: AppReducer.ActionSender?
#endif
    private func sessionChanged(data: SessionChanged.T) {
        windowService.closeActiveWindows(except: [SysexGuideWindowController.self])

        switch data {
        case .established(let vpnGateway):
            if appSessionManager.sessionStatus != .established {
                log.error("Expected session to be established when receiving gateway")
            }
            self.vpnGateway = vpnGateway
            switch appStateManager.state {
            case .disconnected, .aborted:
                if let username = authKeychain.username, propertiesManager.getAutoConnect(for: username).enabled {
                    vpnGateway.autoConnect()
                }
            default:
                break
            }

            if appHasPresented {
                showSidebar()
            }
        case .lost(let loginError):
            showLogIn(initialError: loginError)
        }
    }

    func loginViewModel() -> LoginViewModel {
        LoginViewModel(factory: factory)
    }
    
    private func showLogIn(initialError: String? = nil) {
        appHasPresented = true
#if REDESIGN
        sendAction?(.showLogin(.showError(initialError: initialError)))
#else
        let viewModel = loginViewModel()
        viewModel.initialError = initialError
        windowService.showLogin(viewModel: viewModel)
        NSApp.activate(ignoringOtherApps: true)
#endif
    }
    
    private func attemptSilentLogIn() {
        let viewModel = LoginViewModel(factory: factory)
        viewModel.logInSilently()
    }
    
    private func showSidebar() {
        appHasPresented = true
#if REDESIGN
        sendAction?(.logIn(.init()))
#else
        windowService.showSidebar(appStateManager: appStateManager, vpnGateway: vpnGateway)
#endif
    }
    
    func handleSilentLoginFailure() {
        showLogIn()
    }

    func showReportBug() {
        windowService.closeIfPresent(windowController: ReportBugWindowController.self)
        let viewModel = factory.makeReportBugViewModel()
        windowService.openReportBugWindow(viewModel: viewModel, alertService: alertService)
    }
}

// MARK: - Menu controllers extension

extension NavigationService {
    
    func openAbout(factory: AboutViewController.Factory) {
        guard !windowService.showIfPresent(windowController: AboutWindowController.self) else { return }
        windowService.openAbout(factory: factory)
    }
    
    func openAcknowledgements() {
        guard !windowService.showIfPresent(windowController: AcknowledgementsWindowController.self) else { return }
        windowService.openAcknowledgements()
    }
    
    func checkForUpdates() {
        updateManager.checkForUpdates(appSessionManager, silently: false)
    }
    
    func openLogsFolder(filename: String? = nil) {
        let logFileManager = factory.makeLogFileManager()
        let filename = filename ?? AppConstants.Filenames.appLogFilename
        NSWorkspace.shared.activateFileViewerSelecting([logFileManager.getFileUrl(named: filename)])
    }
    
    func openSettings(to tab: SettingsTab) {
        windowService.closeIfPresent(windowController: SettingsWindowController.self)
        
        windowService.openSettingsWindow(viewModel: SettingsContainerViewModel(factory: factory),
                                         tabBarViewModel: SettingsTabBarViewModel(initialTab: tab),
                                         accountViewModel: AccountViewModel(vpnKeychain: factory.makeVpnKeychain(),
                                                                            sessionService: factory.makeSessionService(),
                                                                            authKeychain: factory.makeAuthKeychainHandle()))
    }
    
    func logOutRequested() {
        appSessionManager.logOut()
    }
    
    func showApplication() {
        appHasPresented = true
        openRequiredWindow()
    }
    
    func openProfiles(_ initialTab: ProfilesTab) {
        guard !windowService.showIfPresent(windowController: ProfilesWindowController.self) else { return }

        windowService.openProfilesWindow(viewModel: ProfilesContainerViewModel(initialTab: initialTab, vpnGateway: vpnGateway))
    }
    
    @objc private func powerOff(_ notification: Notification) {
        log.debug("System user is being logged off", category: .os)
        isSystemLoggingOff = true
    }
    
    private func openRequiredWindow() {
        if !windowService.bringWindowsToForeground() {
            if appSessionManager.sessionStatus == .established {
                showSidebar()
            } else {
                showLogIn()
            }

            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
        
        // Addresses bug where menu bar becomes active when switching from .accessory to .regular mode
        if (NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate(options: []))! {
            dispatch_after_delay(0.1, queue: .main) {
                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
        }
    }
}

// MARK: - AppDelegate extension

extension NavigationService {
    
    func handleApplicationReopen() -> Bool {
        appHasPresented = true

        windowService.closeActiveWindows()
        openRequiredWindow()
        
        return false
    }
    
    func handleApplicationShouldTerminate() -> NSApplication.TerminateReply {
        guard isSystemLoggingOff else {
            appSessionManager.replyToApplicationShouldTerminate()
            return .terminateLater
        }
        
        // Do not show disconnect modal, because user asked for macOS logOff/shutdown
        // Make sure to disconnect the gateway and disable the firewall before logOff/shutdown
        
        guard vpnGateway.connection != .disconnected else {
            return .terminateNow
        }
        
        vpnGateway.disconnect {
            DispatchQueue.main.async {
                self.isSystemLoggingOff = false
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        
        return .terminateLater
    }
}
